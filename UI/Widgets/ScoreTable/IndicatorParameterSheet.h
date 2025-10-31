//
//  IndicatorParameterSheet.h
//  TradingApp
//
//  Parameter Configuration Sheet for Indicators
//

#import <Cocoa/Cocoa.h>
#import "ScoreTableWidget_Models.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Sheet controller for editing indicator-specific parameters
 */
@interface IndicatorParameterSheet : NSObject

#pragma mark - Sheet Presentation

/**
 * Show parameter sheet as modal sheet on window
 * @param indicator Indicator to configure
 * @param window Parent window
 * @param completion Called when done (YES = saved, NO = cancelled)
 * @return Instance of the sheet (keep strong reference to prevent dealloc)
 */
+ (instancetype)showSheetForIndicator:(IndicatorConfig *)indicator
                             onWindow:(NSWindow *)window
                           completion:(void(^)(BOOL saved))completion;

@end

NS_ASSUME_NONNULL_END
