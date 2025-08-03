//
//  VolumeRenderer.h
//  TradingApp
//
//  Renders volume histogram charts
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "IndicatorRenderer.h"
#import "IndicatorSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface VolumeRenderer : NSObject <IndicatorRenderer>

#pragma mark - Properties
@property (nonatomic, strong) IndicatorSettings *settings;

#pragma mark - Customization
@property (nonatomic, strong) NSColor *upVolumeColor;
@property (nonatomic, strong) NSColor *downVolumeColor;
@property (nonatomic, assign) BOOL showMovingAverage;
@property (nonatomic, assign) NSInteger movingAveragePeriod;

@end

NS_ASSUME_NONNULL_END
