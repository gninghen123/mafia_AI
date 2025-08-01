//
//  DataManager+AISummary.h
//  mafia_AI
//
//  Estensione DataManager per gestire richieste AI Summary
//

#import "DataManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataManager (AISummary)

// AI Summary request che segue l'architettura standard
- (void)requestAISummaryForURL:(NSString *)url
                    completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

// Request AI summary con parametri aggiuntivi
- (void)requestAISummaryForURL:(NSString *)url
                    maxTokens:(NSInteger)maxTokens
                   temperature:(float)temperature
                    completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

// Request AI summary per testo diretto (senza URL)
- (void)requestAISummaryForText:(NSString *)text
                     completion:(void(^)(NSString * _Nullable summary, NSError * _Nullable error))completion;

// Check se il servizio AI è disponibile
- (BOOL)isAISummaryServiceAvailable;

// Get configuration per AI service
- (NSDictionary *)getAIServiceConfiguration;

@end

NS_ASSUME_NONNULL_END
