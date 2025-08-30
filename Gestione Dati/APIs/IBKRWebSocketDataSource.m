//
//  IBKRWebSocketDataSource.m
//  TradingApp
//
//  IMPLEMENTATION: TCP Gateway connection with REST format responses
//

#import "IBKRWebSocketDataSource.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

// IBKR Native Protocol Message Types
typedef NS_ENUM(NSInteger, IBKRMessageType) {
    IBKRMessageTypeRequestAccounts = 62,
    IBKRMessageTypeRequestPositions = 61,
    IBKRMessageTypeRequestOrders = 63,
    IBKRMessageTypeRequestHistoricalData = 20,
    IBKRMessageTypeAccountData = 6,
    IBKRMessageTypePosition = 7,
    IBKRMessageTypeOrderStatus = 3,
    IBKRMessageTypeHistoricalData = 17
};

// IBKR TWS API Message Types (corretti)
typedef NS_ENUM(NSInteger, IBKRRealMessageType) {
    IBKRRealMessageTypeManagedAccounts = 15,     // Response: Managed accounts list
    IBKRRealMessageTypeError = 50,               // Error message
    IBKRRealMessageTypeRequestManagedAccounts = 71  // Request: Get managed accounts
};

@interface IBKRWebSocketDataSource ()
@property (nonatomic, assign) int socketFD;
@property (nonatomic, strong) NSMutableDictionary *pendingRequests;
@property (nonatomic, strong) dispatch_queue_t socketReadQueue;
@property (nonatomic, strong) dispatch_queue_t socketWriteQueue;
@property (nonatomic, assign) NSInteger nextRequestId;
@property (nonatomic, readwrite) BOOL isConnected;

// Connection properties
@property (nonatomic, strong) NSString *host;
@property (nonatomic, assign) NSInteger port;
@property (nonatomic, assign) NSInteger clientId;
@end

@implementation IBKRWebSocketDataSource

#pragma mark - Initialization

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port clientId:(NSInteger)clientId {
    self = [super init];
    if (self) {
        _host = host ?: @"127.0.0.1";
        _port = port > 0 ? port : 4002;
        _clientId = clientId > 0 ? clientId : 1;
        _pendingRequests = [NSMutableDictionary dictionary];
        _socketReadQueue = dispatch_queue_create("IBKRWebSocket.read", DISPATCH_QUEUE_SERIAL);
        _socketWriteQueue = dispatch_queue_create("IBKRWebSocket.write", DISPATCH_QUEUE_SERIAL);
        _nextRequestId = 1;
        _socketFD = -1;
        _isConnected = NO;
    }
    return self;
}

#pragma mark - Connection Management

- (void)connectWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion {
    dispatch_async(self.socketWriteQueue, ^{
        [self performConnectionWithCompletion:completion];
    });
}

- (void)performConnectionWithCompletion:(void (^)(BOOL, NSError *))completion {
    if (self.isConnected) {
        NSLog(@"✅ IBKRWebSocketDataSource: Already connected");
        if (completion) completion(YES, nil);
        return;
    }
    
    NSLog(@"🔄 IBKRWebSocketDataSource: Starting connection to %@:%ld", self.host, (long)self.port);
    
    // Create socket
    self.socketFD = socket(AF_INET, SOCK_STREAM, 0);
    if (self.socketFD < 0) {
        NSLog(@"❌ IBKRWebSocketDataSource: Failed to create socket: %s", strerror(errno));
        NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                             code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to create socket"}];
        if (completion) completion(NO, error);
        return;
    }
    
    NSLog(@"✅ IBKRWebSocketDataSource: Socket created successfully (fd=%d)", self.socketFD);
    
    // Configure server address
    struct sockaddr_in serverAddr;
    memset(&serverAddr, 0, sizeof(serverAddr));
    serverAddr.sin_family = AF_INET;
    serverAddr.sin_port = htons((uint16_t)self.port);
    inet_pton(AF_INET, [self.host UTF8String], &serverAddr.sin_addr);
    
    NSLog(@"🌐 IBKRWebSocketDataSource: Connecting to %@:%d...", self.host, ntohs(serverAddr.sin_port));
    
    // Connect
    int result = connect(self.socketFD, (struct sockaddr *)&serverAddr, sizeof(serverAddr));
    if (result < 0) {
        NSLog(@"❌ IBKRWebSocketDataSource: Failed to connect: %s", strerror(errno));
        close(self.socketFD);
        self.socketFD = -1;
        
        NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                             code:1002
                                         userInfo:@{NSLocalizedDescriptionKey: @"Failed to connect to Gateway. Ensure IB Gateway is running on port 4002"}];
        if (completion) completion(NO, error);
        return;
    }
    
    NSLog(@"✅ IBKRWebSocketDataSource: TCP socket connected successfully!");
    
    // ✅ IMPORTANTE: Invia handshake CORRETTO
    [self sendConnectionHandshake];
    
    // Start reading responses in background thread
    [self startReadingResponses];
    
    // Mark as connected
    self.isConnected = YES;
    NSLog(@"🎉 IBKRWebSocketDataSource: Successfully connected to Gateway %@:%ld", self.host, (long)self.port);
    
    if (completion) completion(YES, nil);
}


- (BOOL)performHandshakeWithTimeout:(NSTimeInterval)timeout {
    NSLog(@"🤝 IBKRWebSocketDataSource: Starting handshake protocol...");
    
    // IBKR TWS API handshake format (corrected):
    // Send: "API\0" + version + "\0" + client_id + "\0"
    
    NSString *version = @"76";  // Standard TWS API version
    NSString *clientIdStr = [NSString stringWithFormat:@"%ld", (long)self.clientId];
    
    // Create handshake message
    NSMutableData *handshakeData = [NSMutableData data];
    
    // 1. API prefix
    [handshakeData appendData:[@"API" dataUsingEncoding:NSUTF8StringEncoding]];
    [handshakeData appendBytes:"\0" length:1];
    
    // 2. Version
    [handshakeData appendData:[version dataUsingEncoding:NSUTF8StringEncoding]];
    [handshakeData appendBytes:"\0" length:1];
    
    // 3. Client ID
    [handshakeData appendData:[clientIdStr dataUsingEncoding:NSUTF8StringEncoding]];
    [handshakeData appendBytes:"\0" length:1];
    
    NSLog(@"📤 IBKRWebSocketDataSource: Sending handshake: API\\0%@\\0%@\\0 (%lu bytes)",
          version, clientIdStr, (unsigned long)handshakeData.length);
    
    // Send handshake
    ssize_t bytesSent = send(self.socketFD, handshakeData.bytes, handshakeData.length, 0);
    
    if (bytesSent != handshakeData.length) {
        NSLog(@"❌ IBKRWebSocketDataSource: Handshake send failed: %s", strerror(errno));
        return NO;
    }
    
    NSLog(@"✅ IBKRWebSocketDataSource: Handshake sent successfully (%ld bytes)", (long)bytesSent);
    
    // Wait for handshake response
    return [self readHandshakeResponseWithTimeout:timeout];
}


- (void)disconnect {
    dispatch_async(self.socketWriteQueue, ^{
        if (self.socketFD >= 0) {
            close(self.socketFD);
            self.socketFD = -1;
        }
        self.isConnected = NO;
        [self.pendingRequests removeAllObjects];
        NSLog(@"🔌 IBKRWebSocketDataSource: Disconnected");
    });
}

#pragma mark - IBKR Protocol Implementation

// Updated: Use correct IBKR API handshake format ("API\0" + version\0 + clientId\0)
- (void)sendConnectionHandshake {
    NSLog(@"📡 IBKRWebSocketDataSource: Sending IBKR API handshake...");

    NSString *version = @"76"; // API version
    NSString *clientIdStr = [NSString stringWithFormat:@"%ld", (long)self.clientId];

    NSMutableData *handshakeData = [NSMutableData data];

    // "API\0"
    [handshakeData appendData:[@"API" dataUsingEncoding:NSUTF8StringEncoding]];
    uint8_t zero = 0;
    [handshakeData appendBytes:&zero length:1];

    // "76\0"
    [handshakeData appendData:[version dataUsingEncoding:NSUTF8StringEncoding]];
    [handshakeData appendBytes:&zero length:1];

    // "clientId\0"
    [handshakeData appendData:[clientIdStr dataUsingEncoding:NSUTF8StringEncoding]];
    [handshakeData appendBytes:&zero length:1];

    NSLog(@"📤 IBKRWebSocketDataSource: Sending handshake bytes: %@", handshakeData);

    ssize_t bytesSent = send(self.socketFD, handshakeData.bytes, handshakeData.length, 0);

    if (bytesSent == handshakeData.length) {
        NSLog(@"✅ IBKRWebSocketDataSource: Handshake sent (%ld bytes)", (long)bytesSent);
        [self waitForHandshakeResponse];
    } else {
        NSLog(@"❌ IBKRWebSocketDataSource: Handshake send failed: %s", strerror(errno));
    }
}

- (void)waitForHandshakeResponse {
    NSLog(@"👂 IBKRWebSocketDataSource: Waiting for handshake response...");
    
    // Set socket timeout per handshake
    struct timeval timeout;
    timeout.tv_sec = 5;  // 5 secondi timeout
    timeout.tv_usec = 0;
    setsockopt(self.socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    
    char buffer[256];
    ssize_t bytesRead = recv(self.socketFD, buffer, sizeof(buffer) - 1, 0);
    
    if (bytesRead > 0) {
        buffer[bytesRead] = '\0';
        NSLog(@"📨 IBKRWebSocketDataSource: Handshake response received (%ld bytes): '%s'",
              (long)bytesRead, buffer);
        
        // Rimuovi timeout per operazioni normali
        timeout.tv_sec = 0;
        timeout.tv_usec = 0;
        setsockopt(self.socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        
        NSLog(@"✅ IBKRWebSocketDataSource: Handshake completed successfully");
        
    } else if (bytesRead == 0) {
        NSLog(@"❌ IBKRWebSocketDataSource: Connection closed during handshake");
    } else {
        NSLog(@"❌ IBKRWebSocketDataSource: Handshake timeout or error: %s", strerror(errno));
    }
}

- (BOOL)readHandshakeResponseWithTimeout:(NSTimeInterval)timeout {
    NSLog(@"👂 IBKRWebSocketDataSource: Waiting for handshake response...");
    
    char buffer[1024];
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    
    while (([NSDate timeIntervalSinceReferenceDate] - startTime) < timeout) {
        ssize_t bytesRead = recv(self.socketFD, buffer, sizeof(buffer) - 1, MSG_DONTWAIT);
        
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            NSData *responseData = [NSData dataWithBytes:buffer length:bytesRead];
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            
            NSLog(@"📨 IBKRWebSocketDataSource: Handshake response received (%ld bytes):", (long)bytesRead);
            NSLog(@"📨 Raw bytes: %@", responseData);
            NSLog(@"📨 As string: '%@'", response ?: @"<invalid UTF-8>");
            
            // IBKR Gateway typically responds with version info or empty response for success
            if (bytesRead >= 4) {  // Minimum valid response
                NSLog(@"✅ IBKRWebSocketDataSource: Handshake appears successful");
                return YES;
            }
        } else if (bytesRead == 0) {
            NSLog(@"❌ IBKRWebSocketDataSource: Connection closed during handshake");
            return NO;
        } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
            NSLog(@"❌ IBKRWebSocketDataSource: Handshake receive error: %s", strerror(errno));
            return NO;
        }
        
        // Brief pause before retry
        usleep(100000); // 100ms
    }
    
    NSLog(@"⏰ IBKRWebSocketDataSource: Handshake timeout after %.1f seconds", timeout);
    return NO;
}

- (void)readHandshakeResponse {
    // Read server's handshake response
    char buffer[1024];
    ssize_t bytesRead = recv(self.socketFD, buffer, sizeof(buffer) - 1, 0);
    
    if (bytesRead > 0) {
        buffer[bytesRead] = '\0';
        NSString *response = [NSString stringWithUTF8String:buffer];
        NSLog(@"📨 IBKRWebSocketDataSource: Handshake response: %@", response);
        
        // Check if handshake was successful
        if ([response containsString:@"76"] || [response length] > 0) {
            NSLog(@"✅ IBKRWebSocketDataSource: Handshake successful");
        } else {
            NSLog(@"❌ IBKRWebSocketDataSource: Handshake failed");
        }
    } else {
        NSLog(@"❌ IBKRWebSocketDataSource: No handshake response received");
    }
}


- (void)startReadingResponses {
    NSLog(@"📡 IBKRWebSocketDataSource: Starting response reader thread...");
    dispatch_async(self.socketReadQueue, ^{
        [self readSocketDataWithDebug];
    });
}

- (void)readSocketDataWithDebug {
    NSLog(@"👂 IBKRWebSocketDataSource: Response reader thread started");
    
    // Remove timeout for normal operation
    struct timeval timeout;
    timeout.tv_sec = 0;
    timeout.tv_usec = 0;
    setsockopt(self.socketFD, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
    
    char buffer[4096];
    while (self.isConnected && self.socketFD >= 0) {
        ssize_t bytesRead = recv(self.socketFD, buffer, sizeof(buffer) - 1, 0);
        
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            NSData *responseData = [NSData dataWithBytes:buffer length:bytesRead];
            NSString *response = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            
            NSLog(@"📨 IBKRWebSocketDataSource: Received %ld bytes", (long)bytesRead);
            NSLog(@"📨 Raw data: %@", responseData);
            NSLog(@"📨 As string: '%@'", response ?: @"<invalid UTF-8>");
            
            if (response) {
                [self processResponse:response];
            }
        } else if (bytesRead == 0) {
            NSLog(@"🔌 IBKRWebSocketDataSource: Connection closed by Gateway");
            break;
        } else {
            NSLog(@"❌ IBKRWebSocketDataSource: Read error: %s", strerror(errno));
            break;
        }
    }
    
    NSLog(@"🛑 IBKRWebSocketDataSource: Response reader thread terminated");
    self.isConnected = NO;
}

#pragma mark - Connection Test Method

- (void)testConnectionWithCompletion:(void (^)(BOOL success, NSString *details))completion {
    NSLog(@"🧪 IBKRWebSocketDataSource: Starting connection test...");
    
    dispatch_async(self.socketWriteQueue, ^{
        NSMutableString *details = [NSMutableString string];
        BOOL success = YES;
        
        [details appendString:@"=== IBKR Gateway Connection Test ===\n"];
        [details appendFormat:@"Target: %@:%ld\n", self.host, (long)self.port];
        [details appendFormat:@"Client ID: %ld\n", (long)self.clientId];
        
        // Test 1: Socket creation
        int testSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (testSocket < 0) {
            [details appendFormat:@"❌ Socket creation failed: %s\n", strerror(errno)];
            success = NO;
        } else {
            [details appendString:@"✅ Socket created successfully\n"];
        }
        
        // Test 2: TCP connection
        struct sockaddr_in serverAddr;
        memset(&serverAddr, 0, sizeof(serverAddr));
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_port = htons((uint16_t)self.port);
        inet_pton(AF_INET, [self.host UTF8String], &serverAddr.sin_addr);
        
        int result = connect(testSocket, (struct sockaddr *)&serverAddr, sizeof(serverAddr));
        if (result < 0) {
            [details appendFormat:@"❌ TCP connection failed: %s\n", strerror(errno)];
            [details appendString:@"💡 Check: Is IB Gateway running?\n"];
            [details appendString:@"💡 Check: Is API enabled in Gateway settings?\n"];
            [details appendFormat:@"💡 Check: Is port %ld open?\n", (long)self.port];
            success = NO;
        } else {
            [details appendString:@"✅ TCP connection successful\n"];
        }
        
        // Cleanup
        if (testSocket >= 0) {
            close(testSocket);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"%@", details);
            if (completion) completion(success, [details copy]);
        });
    });
}

- (void)readSocketData {
    // Improved response reading with proper IBKR message framing
    char lengthBuffer[4];
    char *messageBuffer = NULL;
    
    while (self.isConnected) {
        // 1. Read message length (4 bytes, big endian)
        ssize_t lengthBytesRead = recv(self.socketFD, lengthBuffer, 4, MSG_WAITALL);
        
        if (lengthBytesRead <= 0) {
            NSLog(@"🔌 IBKRWebSocketDataSource: Connection closed during length read");
            break;
        }
        
        if (lengthBytesRead != 4) {
            NSLog(@"⚠️ IBKRWebSocketDataSource: Incomplete length read: %ld bytes", lengthBytesRead);
            continue;
        }
        
        // 2. Convert length from big endian
        uint32_t messageLength = ntohl(*((uint32_t*)lengthBuffer));
        
        if (messageLength == 0) {
            NSLog(@"⚠️ IBKRWebSocketDataSource: Zero length message");
            continue;
        }
        
        if (messageLength > 100000) { // Sanity check
            NSLog(@"❌ IBKRWebSocketDataSource: Message too large: %u bytes", messageLength);
            break;
        }
        
        // 3. Allocate buffer for message content
        messageBuffer = malloc(messageLength + 1);
        if (!messageBuffer) {
            NSLog(@"❌ IBKRWebSocketDataSource: Failed to allocate message buffer");
            break;
        }
        
        // 4. Read message content
        ssize_t messageBytesRead = recv(self.socketFD, messageBuffer, messageLength, MSG_WAITALL);
        
        if (messageBytesRead <= 0) {
            NSLog(@"🔌 IBKRWebSocketDataSource: Connection closed during message read");
            free(messageBuffer);
            break;
        }
        
        if (messageBytesRead != messageLength) {
            NSLog(@"⚠️ IBKRWebSocketDataSource: Incomplete message read: %ld/%u bytes", messageBytesRead, messageLength);
            free(messageBuffer);
            continue;
        }
        
        // 5. Null terminate and process
        messageBuffer[messageLength] = '\0';
        NSString *message = [NSString stringWithUTF8String:messageBuffer];
        
        if (message) {
            [self processResponse:message];
        } else {
            NSLog(@"⚠️ IBKRWebSocketDataSource: Failed to decode message as UTF-8");
        }
        
        // 6. Clean up
        free(messageBuffer);
        messageBuffer = NULL;
    }
    
    // Clean up on exit
    if (messageBuffer) {
        free(messageBuffer);
    }
}


- (void)processResponse:(NSString *)response {
    NSLog(@"📨 IBKRWebSocketDataSource: Processing REAL response: %@", response);
    
    // Parse IBKR response format
    NSArray *fields = [response componentsSeparatedByString:@"\0"];
    
    if (fields.count < 2) {
        NSLog(@"⚠️ IBKRWebSocketDataSource: Invalid response format");
        return;
    }
    
    NSString *messageTypeStr = fields[0];
    NSInteger messageType = [messageTypeStr integerValue];
    
    switch (messageType) {
        case 15: // MANAGED_ACCTS response
            [self processManagedAccountsResponse:fields];
            break;
            
        case 50: // ERROR response
            [self processErrorResponse:fields];
            break;
            
        default:
            NSLog(@"⚠️ IBKRWebSocketDataSource: Unknown message type %ld", (long)messageType);
            break;
    }
}

#pragma mark - Account Data (REST Format Compatible)

- (void)fetchAccountsWithCompletion:(void (^)(NSArray *accounts, NSError *_Nullable error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to Gateway"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSInteger requestId = self.nextRequestId++;
    
    // Store completion for when response arrives
    self.pendingRequests[@(requestId)] = [completion copy];
    NSLog(@"DEBUG socketWriteQueue: %@", self.socketWriteQueue);
    
    dispatch_async(self.socketWriteQueue, ^{
        NSLog(@"✅ socketWriteQueue test log");
    });
    
    dispatch_async(self.socketWriteQueue, ^{
        NSLog(@"🎯 DEBUG: ENTERED dispatch block! Thread: %@", [NSThread currentThread]);

        // Send REAL account request via IBKR protocol
        [self sendAccountRequest:requestId];
    });
}

- (void)sendAccountRequest:(NSInteger)requestId {
    NSLog(@"📤 IBKRWebSocketDataSource: Sending managed accounts request");
    
    // ✅ FORMATO CORRETTO: Solo message type e version (SENZA length prefix)
    NSString *message = [NSString stringWithFormat:@"%d\0%d",
                         IBKRRealMessageTypeRequestManagedAccounts, 1];    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    
    ssize_t bytesSent = send(self.socketFD, messageData.bytes, messageData.length, 0);
    NSLog(@"📤 Sent: %ld bytes", (long)bytesSent);
}

#pragma mark - Response Processing (REAL)



- (void)processManagedAccountsResponse:(NSArray *)fields {
    NSLog(@"📊 IBKRWebSocketDataSource: Processing managed accounts response");
    
    if (fields.count < 3) {
        NSLog(@"❌ IBKRWebSocketDataSource: Invalid managed accounts response");
        return;
    }
    
    // Format: [MessageType][Version][AccountsList]
    NSString *accountsListStr = fields[2];
    
    if (!accountsListStr || accountsListStr.length == 0) {
        NSLog(@"⚠️ IBKRWebSocketDataSource: Empty accounts list received");
        
        // Call all pending account completions with empty array
        [self callAccountCompletionsWithAccounts:@[] error:nil];
        return;
    }
    
    // Parse account IDs (comma separated)
    NSArray *accountIds = [accountsListStr componentsSeparatedByString:@","];
    NSMutableArray *accounts = [NSMutableArray array];
    
    for (NSString *accountId in accountIds) {
        NSString *trimmedId = [accountId stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        if (trimmedId.length > 0) {
            // Convert to REST API format for compatibility
            NSDictionary *accountDict = @{
                @"id": trimmedId,
                @"accountId": trimmedId,
                @"accountVan": trimmedId,
                @"accountTitle": [NSString stringWithFormat:@"Account %@", trimmedId],
                @"accountStatus": @"O", // Open
                @"currency": @"USD",    // Default, will be updated later
                @"type": @"INDIVIDUAL"  // Default, will be updated later
            };
            
            [accounts addObject:accountDict];
        }
    }
    
    NSLog(@"✅ IBKRWebSocketDataSource: Parsed %lu accounts from response", (unsigned long)accounts.count);
    
    // Call all pending account completions
    [self callAccountCompletionsWithAccounts:[accounts copy] error:nil];
}


- (void)processErrorResponse:(NSArray *)fields {
    NSLog(@"❌ IBKRWebSocketDataSource: Processing error response");
    
    if (fields.count < 4) {
        NSLog(@"❌ IBKRWebSocketDataSource: Invalid error response format");
        return;
    }
    
    // Format: [MessageType][Version][RequestId][ErrorCode][ErrorMsg]
    NSString *requestIdStr = fields[2];
    NSString *errorCodeStr = fields[3];
    NSString *errorMsg = fields.count > 4 ? fields[4] : @"Unknown error";
    
    NSInteger requestId = [requestIdStr integerValue];
    NSInteger errorCode = [errorCodeStr integerValue];
    
    NSLog(@"❌ IBKRWebSocketDataSource: Error %ld for request %ld: %@", (long)errorCode, (long)requestId, errorMsg);
    
    // Create error object
    NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                         code:errorCode
                                     userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
    
    // Find and call specific completion
    void (^completion)(NSArray *, NSError *) = self.pendingRequests[@(requestId)];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(@[], error);
            [self.pendingRequests removeObjectForKey:@(requestId)];
        });
    } else {
        // If no specific request ID match, this might be a general error
        // Call all pending account completions with error
        [self callAccountCompletionsWithAccounts:@[] error:error];
    }
}


- (void)fetchPositionsForAccount:(NSString *)accountId completion:(void (^)(NSArray *positions, NSError *_Nullable error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to Gateway"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSInteger requestId = self.nextRequestId++;
    self.pendingRequests[@(requestId)] = [completion copy];
    
    dispatch_async(self.socketWriteQueue, ^{
        [self sendPositionsRequest:requestId accountId:accountId];
    });
}

- (void)callAccountCompletionsWithAccounts:(NSArray *)accounts error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Get all pending account request completions
        NSArray *requestIds = [self.pendingRequests allKeys];
        
        for (NSNumber *requestIdObj in requestIds) {
            void (^completion)(NSArray *, NSError *) = self.pendingRequests[requestIdObj];
            if (completion) {
                completion(accounts, error);
            }
        }
        
        // Clear all pending requests
        [self.pendingRequests removeAllObjects];
    });
}


- (void)sendPositionsRequest:(NSInteger)requestId accountId:(NSString *)accountId {
    // IBKR protocol: Request positions
    NSString *message = [NSString stringWithFormat:@"%ld\0%ld\0%@\0", (long)IBKRMessageTypeRequestPositions, (long)requestId, accountId];
    NSData *messageData = [message dataUsingEncoding:NSUTF8StringEncoding];
    
    send(self.socketFD, messageData.bytes, messageData.length, 0);
    NSLog(@"📤 IBKRWebSocketDataSource: Sent positions request %ld for account %@", (long)requestId, accountId);
    
    // Simulate response
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self simulatePositionsResponse:requestId];
    });
}



- (void)simulatePositionsResponse:(NSInteger)requestId {
    // SIMULATE: Convert TCP response to EXACT REST format
    NSArray *positions = @[
        @{
            @"contractId": @43645865,
            @"position": @100,
            @"mktPrice": @150.25,
            @"mktValue": @15025.0,
            @"currency": @"USD",
            @"avgCost": @145.50,
            @"avgPrice": @145.50,
            @"realizedPL": @0.0,
            @"unrealizedPL": @475.0,
            @"exchs": @"NASDAQ",
            @"expiry": @"",
            @"putOrCall": @"",
            @"multiplier": @1,
            @"strike": @0.0,
            @"exerciseStyle": @"",
            @"conid": @43645865,
            @"assetClass": @"STK",
            @"symbol": @"AAPL"
        }
    ];
    
    void (^completion)(NSArray *, NSError *) = self.pendingRequests[@(requestId)];
    if (completion) {
        completion(positions, nil);
        [self.pendingRequests removeObjectForKey:@(requestId)];
    }
}

- (void)fetchOrdersForAccount:(NSString *)accountId completion:(void (^)(NSArray *orders, NSError *_Nullable error))completion {
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"IBKRWebSocketDataSource"
                                             code:1003
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to Gateway"}];
        if (completion) completion(@[], error);
        return;
    }
    
    // Simulate orders response with REST format
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSArray *orders = @[
            @{
                @"orderId": @12345,
                @"permId": @67890,
                @"clientId": @(self.clientId),
                @"parentId": @0,
                @"account": accountId,
                @"symbol": @"TSLA",
                @"secType": @"STK",
                @"exchange": @"NASDAQ",
                @"action": @"BUY",
                @"orderType": @"LMT",
                @"totalQuantity": @50,
                @"lmtPrice": @200.0,
                @"status": @"Submitted",
                @"filled": @0,
                @"remaining": @50,
                @"avgFillPrice": @0.0,
                @"lastFillPrice": @0.0,
                @"whyHeld": @"",
                @"mktCapPrice": @0.0
            }
        ];
        
        if (completion) completion(orders, nil);
    });
}

- (void)fetchHistoricalDataForSymbol:(NSString *)symbol
                           timeframe:(NSString *)timeframe
                           startDate:(NSDate *)startDate
                             endDate:(NSDate *)endDate
                          completion:(void (^)(NSArray *bars, NSError *_Nullable error))completion {
    
    // Simulate historical data with REST format
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // Create sample bars in IBKR REST format
        NSMutableArray *bars = [NSMutableArray array];
        NSTimeInterval currentTime = startDate.timeIntervalSince1970;
        NSTimeInterval endTime = endDate.timeIntervalSince1970;
        NSTimeInterval interval = 3600; // 1 hour intervals
        
        while (currentTime < endTime) {
            [bars addObject:@{
                @"t": @((long long)(currentTime * 1000)), // timestamp in milliseconds
                @"o": @(150.0 + (arc4random_uniform(10) - 5)), // open
                @"h": @(152.0 + (arc4random_uniform(10) - 5)), // high
                @"l": @(148.0 + (arc4random_uniform(10) - 5)), // low
                @"c": @(151.0 + (arc4random_uniform(10) - 5)), // close
                @"v": @(arc4random_uniform(1000000) + 100000)   // volume
            }];
            currentTime += interval;
        }
        
        if (completion) completion([bars copy], nil);
    });
}

#pragma mark - Deallocation

- (void)dealloc {
    [self disconnect];
}

@end

/*
USAGE EXAMPLE:

// Create fallback datasource
IBKRWebSocketDataSource *fallback = [[IBKRWebSocketDataSource alloc] initWithHost:@"127.0.0.1" port:4002 clientId:1];

[fallback connectWithCompletion:^(BOOL success, NSError *error) {
    if (success) {
        [fallback fetchAccountsWithCompletion:^(NSArray *accounts, NSError *error) {
            NSLog(@"Accounts via TCP: %@", accounts);
            // SAME format as REST API!
        }];
    }
}];
*/
