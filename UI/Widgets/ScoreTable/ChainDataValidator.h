//
//  ChainDataValidator.h
//  TradingApp
//
//  Validates data received from widget chain
//

#import <Foundation/Foundation.h>
#import "ScoreTableWidget_Models.h"
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Validates chain data against requirements
 */
@interface ChainDataValidator : NSObject

/**
 * Validate chain data for a symbol
 * @param chainData Dictionary with symbol data from chain
 * @param requirements Minimum data requirements
 * @param result Output parameter for validation result
 * @return YES if data is valid and sufficient, NO otherwise
 */
+ (BOOL)validateChainData:(NSDictionary *)chainData
          forRequirements:(DataRequirements *)requirements
                   result:(ValidationResult *_Nullable *_Nullable)result;

/**
 * Validate an array of historical bars
 * @param bars Array of HistoricalBarModel
 * @param requirements Minimum requirements
 * @return ValidationResult
 */
+ (ValidationResult *)validateBars:(NSArray<HistoricalBarModel *> *)bars
                   forRequirements:(DataRequirements *)requirements;

@end

NS_ASSUME_NONNULL_END
