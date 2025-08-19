//
//  ClaudeDataSource.h
//  mafia_AI
//
//  DataSource per Claude AI API
//

#import <Foundation/Foundation.h>
#import "DownloadManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface ClaudeDataSource : NSObject <DataSource>

// Configuration
@property (nonatomic, strong) NSString *apiKey;
@property (nonatomic, strong) NSString *baseURL;
@property (nonatomic, strong) NSString *defaultModel;
@property (nonatomic, assign) NSTimeInterval requestTimeout;

// Initialization
- (instancetype)initWithAPIKey:(NSString *)apiKey;
- (instancetype)initWithAPIKey:(NSString *)apiKey baseURL:(NSString *)baseURL;

// AI Summary methods
- (void)summarizeFromURL:(NSString *)url
              completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

- (void)summarizeFromURL:(NSString *)url
               maxTokens:(NSInteger)maxTokens
             temperature:(float)temperature
              completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

- (void)summarizeText:(NSString *)text
           completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

- (void)summarizeText:(NSString *)text
            maxTokens:(NSInteger)maxTokens
          temperature:(float)temperature
           completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

// Generic Claude API call
- (void)sendMessageToClaudeWithPrompt:(NSString *)prompt
                            maxTokens:(NSInteger)maxTokens
                          temperature:(float)temperature
                           completion:(void(^)(NSString * _Nullable response, NSError * _Nullable error))completion;

// Configuration helpers
+ (instancetype)sharedInstance;
- (void)updateConfiguration:(NSDictionary *)config;
- (BOOL)isConfigured;

@end

NS_ASSUME_NONNULL_END
