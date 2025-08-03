//
//  ChartPanelModel.h
//  TradingApp
//
//  Data model for chart panels
//

#import <Foundation/Foundation.h>
#import "ChartTypes.h"
#import "IndicatorRenderer.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartPanelModel : NSObject

#pragma mark - Core Properties
@property (nonatomic, strong) NSString *panelId;           // Unique identifier
@property (nonatomic, strong) NSString *title;             // Display title
@property (nonatomic, assign) ChartPanelType panelType;    // Main or secondary
@property (nonatomic, assign) CGFloat heightRatio;         // 0.0-1.0 relative height
@property (nonatomic, assign) CGFloat minHeight;           // Minimum height in points

#pragma mark - Indicators
@property (nonatomic, strong) NSMutableArray<id<IndicatorRenderer>> *indicators;

#pragma mark - State
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL canBeDeleted;

#pragma mark - Factory Methods
+ (instancetype)mainPanelWithTitle:(NSString *)title;
+ (instancetype)secondaryPanelWithTitle:(NSString *)title;

#pragma mark - Indicator Management
- (void)addIndicator:(id<IndicatorRenderer>)indicator;
- (void)removeIndicator:(id<IndicatorRenderer>)indicator;
- (void)removeIndicatorAtIndex:(NSInteger)index;
- (BOOL)hasIndicatorOfType:(NSString *)type;
- (nullable id<IndicatorRenderer>)indicatorOfType:(NSString *)type;

#pragma mark - Serialization
- (NSDictionary *)serialize;
- (void)deserialize:(NSDictionary *)data;

@end

NS_ASSUME_NONNULL_END
