//
//  DataManager+AISummary.m (CORRECTED COMPLETE FILE)
//  mafia_AI
//
//  Estensione DataManager per gestire richieste AI Summary
//  UPDATED: Usa la nuova architettura DownloadManager
//

#import "DataManager+AISummary.h"
#import "DownloadManager.h"
#import "CommonTypes.h"

@implementation DataManager (AISummary)

#pragma mark - Public Methods

- (void)requestAISummaryForURL:(NSString *)url
                    completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    // Default parameters
    [self requestAISummaryForURL:url
                       maxTokens:500
                     temperature:0.3
                      completion:completion];
}

- (void)requestAISummaryForURL:(NSString *)url
                    maxTokens:(NSInteger)maxTokens
                   temperature:(float)temperature
                    completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    if (!url || url.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL for AI summary"}];
        if (completion) completion(nil, error);
        return;
    }
    
    if (![self isAISummaryServiceAvailable]) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"AI Summary service not available"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Crea i parametri per la richiesta
    NSDictionary *parameters = @{
        @"symbol": @"AI_URL_SUMMARY", // Simbolo speciale per identificare richieste AI
        @"url": url,
        @"maxTokens": @(maxTokens),
        @"temperature": @(temperature),
        @"requestType": @"newsSummary",
        @"aiRequest": @YES,
        @"model": @"claude-3-haiku-20240307"
    };
    
    NSLog(@"📡 DataManager: Requesting AI summary for URL: %@", url);
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // CORREZIONE: Usa executeMarketDataRequest con preferredSource Claude
    [downloadManager executeMarketDataRequest:DataRequestTypeQuote
                                   parameters:parameters
                               preferredSource:DataSourceTypeClaude
                                   completion:^(id _Nullable data, DataSourceType usedSource, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ DataManager: AI summary request failed: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }
            
            // Verifica che sia stato usato Claude
            if (usedSource != DataSourceTypeClaude) {
                NSLog(@"❌ DataManager: Expected Claude DataSource but got %ld", (long)usedSource);
                NSError *sourceError = [NSError errorWithDomain:@"DataManager"
                                                           code:501
                                                       userInfo:@{NSLocalizedDescriptionKey: @"AI request not handled by Claude"}];
                if (completion) completion(nil, sourceError);
                return;
            }
            
            NSString *summary = [self parseAISummaryResponse:data];
            
            if (summary && summary.length > 0) {
                NSLog(@"✅ DataManager: AI summary successful (%lu characters)", (unsigned long)summary.length);
                if (completion) completion(summary, nil);
            } else {
                NSLog(@"❌ DataManager: Failed to parse AI response or empty summary");
                NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse AI response or empty summary"}];
                if (completion) completion(nil, parseError);
            }
        });
    }];
}

- (void)requestAISummaryForText:(NSString *)text
                     completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion {
    
    if (!text || text.length == 0) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid text for AI summary"}];
        if (completion) completion(nil, error);
        return;
    }
    
    if (![self isAISummaryServiceAvailable]) {
        NSError *error = [NSError errorWithDomain:@"DataManager"
                                             code:503
                                         userInfo:@{NSLocalizedDescriptionKey: @"AI Summary service not available"}];
        if (completion) completion(nil, error);
        return;
    }
    
    // Crea i parametri per la richiesta
    NSDictionary *parameters = @{
        @"symbol": @"AI_TEXT_SUMMARY", // Simbolo speciale per identificare richieste AI
        @"text": text,
        @"maxTokens": @(500),
        @"temperature": @(0.3),
        @"requestType": @"textSummary",
        @"aiRequest": @YES,
        @"model": @"claude-3-haiku-20240307"
    };
    
    NSLog(@"📡 DataManager: Requesting AI summary for text (%lu characters)", (unsigned long)text.length);
    
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    // CORREZIONE: Usa executeMarketDataRequest con preferredSource Claude
    [downloadManager executeMarketDataRequest:DataRequestTypeQuote
                                   parameters:parameters
                               preferredSource:DataSourceTypeClaude
                                   completion:^(id _Nullable data, DataSourceType usedSource, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"❌ DataManager: AI text summary failed: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }
            
            // Verifica che sia stato usato Claude
            if (usedSource != DataSourceTypeClaude) {
                NSLog(@"❌ DataManager: AI request not handled by Claude (source: %ld)", (long)usedSource);
                NSError *sourceError = [NSError errorWithDomain:@"DataManager"
                                                           code:501
                                                       userInfo:@{NSLocalizedDescriptionKey: @"AI request not processed by Claude AI"}];
                if (completion) completion(nil, sourceError);
                return;
            }
            
            NSString *summary = [self parseAISummaryResponse:data];
            
            if (summary && summary.length > 0) {
                NSLog(@"✅ DataManager: AI text summary successful (%lu chars)", (unsigned long)summary.length);
                if (completion) completion(summary, nil);
            } else {
                NSLog(@"❌ DataManager: Empty or invalid AI response");
                NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Empty or invalid AI response"}];
                if (completion) completion(nil, parseError);
            }
        });
    }];
}

- (BOOL)isAISummaryServiceAvailable {
    // Check if Claude API is configured and available
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    return [downloadManager isDataSourceConnected:DataSourceTypeClaude];
}

- (NSDictionary *)getAIServiceConfiguration {
    // Read from app settings or config file
    return @{
        @"apiKey": @"your-claude-api-key",  // TODO: Load from secure storage
        @"baseURL": @"https://api.anthropic.com/v1/messages",
        @"model": @"claude-3-haiku-20240307",
        @"maxTokens": @(500),
        @"temperature": @(0.3),
        @"timeout": @(30.0)
    };
}

#pragma mark - Private Helpers

- (NSString *)parseAISummaryResponse:(id)responseData {
    if (!responseData) {
        NSLog(@"❌ DataManager: Received nil response data");
        return nil;
    }
    
    // Se è già una stringa, ritornala
    if ([responseData isKindOfClass:[NSString class]]) {
        NSString *result = (NSString *)responseData;
        return result.length > 0 ? result : nil;
    }
    
    // Se è un dictionary (response Claude API)
    if ([responseData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *response = (NSDictionary *)responseData;
        
        // Claude API response format
        NSArray *content = response[@"content"];
        if (content && [content isKindOfClass:[NSArray class]] && content.count > 0) {
            id firstContent = content[0];
            if ([firstContent isKindOfClass:[NSDictionary class]]) {
                NSDictionary *contentDict = (NSDictionary *)firstContent;
                NSString *text = contentDict[@"text"];
                if (text && [text isKindOfClass:[NSString class]]) {
                    return text.length > 0 ? text : nil;
                }
            }
        }
        
        // Fallback: look for common summary fields
        NSString *summary = response[@"summary"];
        if (summary && [summary isKindOfClass:[NSString class]]) {
            return summary.length > 0 ? summary : nil;
        }
        
        NSString *text = response[@"text"];
        if (text && [text isKindOfClass:[NSString class]]) {
            return text.length > 0 ? text : nil;
        }
        
        NSString *message = response[@"message"];
        if (message && [message isKindOfClass:[NSString class]]) {
            return message.length > 0 ? message : nil;
        }
        
        // Debug: log available keys
        NSLog(@"❌ DataManager: Could not extract text from Claude response. Available keys: %@", response.allKeys);
    }
    
    // Se è NSData, prova a convertire in JSON
    if ([responseData isKindOfClass:[NSData class]]) {
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:(NSData *)responseData
                                                        options:0
                                                          error:&jsonError];
        if (!jsonError && jsonObject) {
            return [self parseAISummaryResponse:jsonObject];
        } else {
            NSLog(@"❌ DataManager: JSON parsing error: %@", jsonError.localizedDescription);
        }
    }
    
    NSLog(@"❌ DataManager: Could not parse AI response of type %@", NSStringFromClass([responseData class]));
    return nil;
}

@end
