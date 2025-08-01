//
//  ClaudeDataSource.m
//  mafia_AI
//

#import "ClaudeDataSource.h"
#import "CommonTypes.h"

@interface ClaudeDataSource ()
@property (nonatomic, strong) NSURLSession *urlSession;
@property (nonatomic, assign) BOOL connected;
@end

@implementation ClaudeDataSource

+ (instancetype)sharedInstance {
    static ClaudeDataSource *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Load API key from settings/keychain in production
        sharedInstance = [[self alloc] initWithAPIKey:@"your-claude-api-key-here"];
    });
    return sharedInstance;
}

- (instancetype)initWithAPIKey:(NSString *)apiKey {
    return [self initWithAPIKey:apiKey baseURL:@"https://api.anthropic.com/v1/messages"];
}

- (instancetype)initWithAPIKey:(NSString *)apiKey baseURL:(NSString *)baseURL {
    self = [super init];
    if (self) {
        _apiKey = [apiKey copy];
        _baseURL = [baseURL copy];
        _defaultModel = @"claude-3-haiku-20240307";
        _requestTimeout = 30.0;
        _connected = NO;
        
        // Configure URL session
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.timeoutIntervalForRequest = _requestTimeout;
        config.timeoutIntervalForResource = _requestTimeout * 2;
        _urlSession = [NSURLSession sessionWithConfiguration:config];
        
        NSLog(@"ClaudeDataSource: Initialized with base URL: %@", _baseURL);
    }
    return self;
}

#pragma mark - DataSource Protocol

- (DataSourceType)sourceType {
    return DataSourceTypeClaude;
}

- (DataSourceCapabilities)capabilities {
    return DataSourceCapabilityAI;
}

- (NSString *)sourceName {
    return @"Claude AI";
}

- (BOOL)isConnected {
    return self.connected;
}

- (void)connectWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    if (!self.apiKey || self.apiKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"ClaudeDataSource"
                                             code:401
                                         userInfo:@{NSLocalizedDescriptionKey: @"Claude API key not configured"}];
        if (completion) completion(NO, error);
        return;
    }
    
    // Test connection with a simple request
    [self sendMessageToClaudeWithPrompt:@"Hello, are you working?"
                              maxTokens:10
                            temperature:0.1
                             completion:^(NSString * _Nullable response, NSError * _Nullable error) {
        if (error) {
            self.connected = NO;
            NSLog(@"ClaudeDataSource: Connection test failed: %@", error.localizedDescription);
            if (completion) completion(NO, error);
        } else {
            self.connected = YES;
            NSLog(@"ClaudeDataSource: Connected successfully");
            if (completion) completion(YES, nil);
        }
    }];
}

- (void)disconnect {
    self.connected = NO;
    [self.urlSession invalidateAndCancel];
    
    // Recreate session for future use
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = self.requestTimeout;
    config.timeoutIntervalForResource = self.requestTimeout * 2;
    self.urlSession = [NSURLSession sessionWithConfiguration:config];
    
    NSLog(@"ClaudeDataSource: Disconnected");
}

#pragma mark - AI Summary Methods

- (void)summarizeFromURL:(NSString *)url
              completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    [self summarizeFromURL:url maxTokens:500 temperature:0.3 completion:completion];
}

- (void)summarizeFromURL:(NSString *)url
               maxTokens:(NSInteger)maxTokens
             temperature:(float)temperature
              completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"ClaudeDataSource"
                                             code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to Claude API"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // First, fetch the content from the URL
    [self fetchContentFromURL:url completion:^(NSString * _Nullable content, NSError * _Nullable fetchError) {
        if (fetchError || !content) {
            NSError *error = fetchError ?: [NSError errorWithDomain:@"ClaudeDataSource"
                                                               code:400
                                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to fetch URL content"}];
            if (completion) completion(nil, error);
            return;
        }
        
        // Create summarization prompt
        NSString *prompt = [NSString stringWithFormat:
            @"Please provide a concise summary of the following news article. "
            @"Focus on the key points, companies mentioned, and any market-relevant information. "
            @"Keep the summary under 200 words and highlight any stock symbols or financial impacts.\n\n"
            @"Article content:\n%@", content];
        
        [self sendMessageToClaudeWithPrompt:prompt
                                  maxTokens:maxTokens
                                temperature:temperature
                                 completion:completion];
    }];
}

- (void)summarizeText:(NSString *)text
           completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    [self summarizeText:text maxTokens:500 temperature:0.3 completion:completion];
}

- (void)summarizeText:(NSString *)text
            maxTokens:(NSInteger)maxTokens
          temperature:(float)temperature
           completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    if (!self.isConnected) {
        NSError *error = [NSError errorWithDomain:@"ClaudeDataSource"
                                             code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not connected to Claude API"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSString *prompt = [NSString stringWithFormat:
        @"Please provide a concise summary of the following text. "
        @"Focus on the key points and any market-relevant information. "
        @"Keep the summary under 200 words.\n\n"
        @"Text:\n%@", text];
    
    [self sendMessageToClaudeWithPrompt:prompt
                              maxTokens:maxTokens
                            temperature:temperature
                             completion:completion];
}

#pragma mark - Core Claude API Communication

- (void)sendMessageToClaudeWithPrompt:(NSString *)prompt
                            maxTokens:(NSInteger)maxTokens
                          temperature:(float)temperature
                           completion:(void(^)(NSString * _Nullable response, NSError * _Nullable error))completion {
    
    if (!prompt || prompt.length == 0) {
        NSError *error = [NSError errorWithDomain:@"ClaudeDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Empty prompt"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSURL *url = [NSURL URLWithString:self.baseURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    // Set headers
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey] forHTTPHeaderField:@"Authorization"];
    
    // Create request body
    NSDictionary *message = @{
        @"role": @"user",
        @"content": prompt
    };
    
    NSDictionary *requestBody = @{
        @"model": self.defaultModel,
        @"max_tokens": @(maxTokens),
        @"temperature": @(temperature),
        @"messages": @[message]
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestBody
                                                       options:0
                                                         error:&jsonError];
    
    if (jsonError) {
        if (completion) completion(nil, jsonError);
        return;
    }
    
    request.HTTPBody = jsonData;
    
    NSLog(@"ClaudeDataSource: Sending request to Claude API (prompt length: %lu)", (unsigned long)prompt.length);
    
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithRequest:request
                                                    completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"ClaudeDataSource: Request failed: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"Claude API returned status %ld", (long)httpResponse.statusCode];
                NSError *apiError = [NSError errorWithDomain:@"ClaudeDataSource"
                                                        code:httpResponse.statusCode
                                                    userInfo:@{NSLocalizedDescriptionKey: errorMsg}];
                if (completion) completion(nil, apiError);
                return;
            }
            
            if (!data) {
                NSError *noDataError = [NSError errorWithDomain:@"ClaudeDataSource"
                                                           code:500
                                                       userInfo:@{NSLocalizedDescriptionKey: @"No data received from Claude API"}];
                if (completion) completion(nil, noDataError);
                return;
            }
            
            // Parse response
            NSError *parseError;
            id jsonResponse = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
            
            if (parseError) {
                if (completion) completion(nil, parseError);
                return;
            }
            
            NSString *responseText = [self extractTextFromClaudeResponse:jsonResponse];
            
            if (responseText) {
                NSLog(@"ClaudeDataSource: Successfully received response (%lu characters)", (unsigned long)responseText.length);
                if (completion) completion(responseText, nil);
            } else {
                NSError *extractError = [NSError errorWithDomain:@"ClaudeDataSource"
                                                            code:500
                                                        userInfo:@{NSLocalizedDescriptionKey: @"Could not extract text from Claude response"}];
                if (completion) completion(nil, extractError);
            }
        });
    }];
    
    [task resume];
}

#pragma mark - Configuration

- (void)updateConfiguration:(NSDictionary *)config {
    NSString *newApiKey = config[@"apiKey"];
    if (newApiKey) {
        self.apiKey = newApiKey;
    }
    
    NSString *newBaseURL = config[@"baseURL"];
    if (newBaseURL) {
        self.baseURL = newBaseURL;
    }
    
    NSString *newModel = config[@"model"];
    if (newModel) {
        self.defaultModel = newModel;
    }
    
    NSNumber *newTimeout = config[@"timeout"];
    if (newTimeout) {
        self.requestTimeout = [newTimeout doubleValue];
    }
    
    NSLog(@"ClaudeDataSource: Configuration updated");
}

- (BOOL)isConfigured {
    return (self.apiKey.length > 0 && self.baseURL.length > 0);
}

#pragma mark - Private Helpers

- (void)fetchContentFromURL:(NSString *)urlString
                 completion:(void(^)(NSString * _Nullable content, NSError * _Nullable error))completion {
    
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"ClaudeDataSource"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL"}];
        if (completion) completion(nil, error);
        return;
    }
    
    NSURLSessionDataTask *task = [self.urlSession dataTaskWithURL:url
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                if (completion) completion(nil, error);
                return;
            }
            
            if (!data) {
                NSError *noDataError = [NSError errorWithDomain:@"ClaudeDataSource"
                                                           code:500
                                                       userInfo:@{NSLocalizedDescriptionKey: @"No content received from URL"}];
                if (completion) completion(nil, noDataError);
                return;
            }
            
            NSString *content = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (!content) {
                // Try other encodings
                content = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
            }
            
            if (content) {
                // Basic HTML stripping (very simple - could be enhanced)
                content = [self stripBasicHTMLFromText:content];
                if (completion) completion(content, nil);
            } else {
                NSError *decodeError = [NSError errorWithDomain:@"ClaudeDataSource"
                                                           code:500
                                                       userInfo:@{NSLocalizedDescriptionKey: @"Could not decode content from URL"}];
                if (completion) completion(nil, decodeError);
            }
        });
    }];
    
    [task resume];
}

- (NSString *)extractTextFromClaudeResponse:(id)response {
    if (![response isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    
    NSDictionary *responseDict = (NSDictionary *)response;
    NSArray *content = responseDict[@"content"];
    
    if (content && content.count > 0) {
        NSDictionary *firstContent = content[0];
        NSString *text = firstContent[@"text"];
        return text;
    }
    
    return nil;
}

- (NSString *)stripBasicHTMLFromText:(NSString *)html {
    if (!html) return nil;
    
    // Very basic HTML tag removal - could be enhanced with proper HTML parsing
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]*>"
                                                                           options:0
                                                                             error:nil];
    NSString *strippedString = [regex stringByReplacingMatchesInString:html
                                                               options:0
                                                                 range:NSMakeRange(0, html.length)
                                                          withTemplate:@""];
    
    // Clean up extra whitespace
    NSRegularExpression *whitespaceRegex = [NSRegularExpression regularExpressionWithPattern:@"\\s+"
                                                                                     options:0
                                                                                       error:nil];
    strippedString = [whitespaceRegex stringByReplacingMatchesInString:strippedString
                                                               options:0
                                                                 range:NSMakeRange(0, strippedString.length)
                                                          withTemplate:@" "];
    
    return [strippedString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)dealloc {
    [self.urlSession invalidateAndCancel];
}

@end
