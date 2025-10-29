//
//  ScoreTableWidget_Models.h
//  TradingApp
//
//  Models for Score Table Widget
//

#import <Foundation/Foundation.h>
#import "RuntimeModels.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Indicator Configuration

/**
 * Configuration for a single indicator column
 */
@interface IndicatorConfig : NSObject <NSCoding>

@property (nonatomic, strong) NSString *indicatorType;      // "DollarVolume", "AscendingLows", etc.
@property (nonatomic, assign) CGFloat weight;               // 0.0 - 100.0
@property (nonatomic, strong) NSString *displayName;        // "Dollar Volume"
@property (nonatomic, strong) NSDictionary *parameters;     // Custom parameters per indicator
@property (nonatomic, assign) BOOL isEnabled;               // Can be disabled without removing

// Convenience initializer
- (instancetype)initWithType:(NSString *)type
                 displayName:(NSString *)displayName
                      weight:(CGFloat)weight
                  parameters:(NSDictionary *)parameters;

// Validation
- (BOOL)isValid;

@end

#pragma mark - Scoring Strategy

/**
 * A scoring strategy contains multiple indicators with their weights
 */
@interface ScoringStrategy : NSObject <NSCoding>

@property (nonatomic, strong) NSString *strategyName;
@property (nonatomic, strong) NSString *strategyId;             // UUID
@property (nonatomic, strong) NSMutableArray<IndicatorConfig *> *indicators;
@property (nonatomic, strong) NSDate *dateCreated;
@property (nonatomic, strong) NSDate *dateModified;

// Validation
- (BOOL)isValid;
- (CGFloat)totalWeight;

// Convenience
+ (instancetype)strategyWithName:(NSString *)name;
- (void)addIndicator:(IndicatorConfig *)indicator;
- (void)removeIndicatorAtIndex:(NSInteger)index;

@end

#pragma mark - Score Result

/**
 * Result of scoring calculation for a single symbol
 */
@interface ScoreResult : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) CGFloat totalScore;                                   // Weighted total
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSNumber *> *indicatorScores;  // Raw scores per indicator
@property (nonatomic, strong) NSDate *calculatedAt;
@property (nonatomic, strong) NSError *error;                                       // If calculation failed

// Convenience
+ (instancetype)resultForSymbol:(NSString *)symbol;
- (void)setScore:(CGFloat)score forIndicator:(NSString *)indicatorType;
- (CGFloat)scoreForIndicator:(NSString *)indicatorType;

@end

#pragma mark - Data Requirements

/**
 * Minimum data requirements for a scoring strategy
 */
@interface DataRequirements : NSObject

@property (nonatomic, assign) NSInteger minimumBars;        // Minimum bars needed
@property (nonatomic, assign) BarTimeframe timeframe;       // Required timeframe
@property (nonatomic, assign) BOOL needsFundamentals;       // If fundamental data needed
@property (nonatomic, strong) NSDate *earliestDate;         // Earliest date needed

+ (instancetype)requirements;

@end

#pragma mark - Validation Result

/**
 * Result of chain data validation
 */
@interface ValidationResult : NSObject

@property (nonatomic, assign) BOOL isValid;
@property (nonatomic, assign) BOOL hasSufficientBars;
@property (nonatomic, assign) BOOL hasCompatibleTimeframe;
@property (nonatomic, strong) NSString *reason;             // Why validation failed
@property (nonatomic, assign) NSInteger missingBars;        // How many bars are missing

+ (instancetype)validResult;
+ (instancetype)invalidResultWithReason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
