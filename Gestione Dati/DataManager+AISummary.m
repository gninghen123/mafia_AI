//
//  DataManager+AISummary.m
//  mafia_AI
//

#import "DataManager+AISummary.h"
#import "DownloadManager.h"
#import "CommonTypes.h"

@implementation DataManager (AISummary)

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
        @"url": url,
        @"maxTokens": @(maxTokens),
        @"temperature": @(temperature),
        @"requestType": @"newsSummary",
        @"model": @"claude-3-haiku-20240307"  // Claude model
    };
    
    NSLog(@"DataManager: Requesting AI summary for URL: %@", url);
    
    // FIXED: Usa il metodo corretto del DownloadManager
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager executeRequest:DataRequestTypeNewsSummary
                         parameters:parameters
                         completion:^(id _Nullable data, DataSourceType usedSource, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"DataManager: AI summary request failed: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }
            
            // Parse response usando ClaudeAdapter
            NSString *summary = [self parseAISummaryResponse:data];
            
            if (summary) {
                NSLog(@"DataManager: AI summary successful (%lu characters)", (unsigned long)summary.length);
                if (completion) completion(summary, nil);
            } else {
                NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse AI response"}];
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
        @"text": text,
        @"maxTokens": @(500),
        @"temperature": @(0.3),
        @"requestType": @"textSummary",
        @"model": @"claude-3-haiku-20240307"
    };
    
    NSLog(@"DataManager: Requesting AI summary for text (%lu characters)", (unsigned long)text.length);
    
    // FIXED: Usa il metodo corretto del DownloadManager
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    [downloadManager executeRequest:DataRequestTypeTextSummary
                         parameters:parameters
                         completion:^(id _Nullable data, DataSourceType usedSource, NSError * _Nullable error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"DataManager: AI text summary request failed: %@", error.localizedDescription);
                if (completion) completion(nil, error);
                return;
            }
            
            NSString *summary = [self parseAISummaryResponse:data];
            
            if (summary) {
                NSLog(@"DataManager: AI text summary successful (%lu characters)", (unsigned long)summary.length);
                if (completion) completion(summary, nil);
            } else {
                NSError *parseError = [NSError errorWithDomain:@"DataManager"
                                                          code:500
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse AI response"}];
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
    // Per ora hardcoded, ma dovrebbe essere configurabile
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
    if (!responseData) return nil;
    
    // Se è già una stringa, ritornala
    if ([responseData isKindOfClass:[NSString class]]) {
        return (NSString *)responseData;
    }
    
    // Se è un dictionary (response Claude API)
    if ([responseData isKindOfClass:[NSDictionary class]]) {
        NSDictionary *response = (NSDictionary *)responseData;
        
        // Claude API response format
        NSArray *content = response[@"content"];
        if (content && content.count > 0) {
            NSDictionary *firstContent = content[0];
            NSString *text = firstContent[@"text"];
            if (text) {
                return text;
            }
        }
        
        // Fallback: look for common summary fields
        NSString *summary = response[@"summary"];
        if (summary) return summary;
        
        NSString *text = response[@"text"];
        if (text) return text;
        
        NSString *message = response[@"message"];
        if (message) return message;
    }
    
    // Se è NSData, prova a convertire in JSON
    if ([responseData isKindOfClass:[NSData class]]) {
        NSError *jsonError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:(NSData *)responseData
                                                        options:0
                                                          error:&jsonError];
        if (!jsonError && jsonObject) {
            return [self parseAISummaryResponse:jsonObject];
        }
    }
    
    NSLog(@"DataManager: Could not parse AI response of type %@", NSStringFromClass([responseData class]));
    return nil;
}

@end
