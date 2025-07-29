//
//  CHChartTypes.m
//  ChartWidget
//
//  Implementation of constants and utility functions for chart types
//

#import "CHChartTypes.h"

// Constants
const CGFloat CHChartDefaultLineWidth = 2.0;
const CGFloat CHChartDefaultBarWidth = 0.8;
const CGFloat CHChartDefaultPointRadius = 4.0;
const NSTimeInterval CHChartDefaultAnimationDuration = 0.3;
const NSInteger CHChartDefaultMaxDataPoints = 1000;

// Notification Names
NSString * const CHChartDataDidChangeNotification = @"CHChartDataDidChangeNotification";
NSString * const CHChartSelectionDidChangeNotification = @"CHChartSelectionDidChangeNotification";
NSString * const CHChartConfigurationDidChangeNotification = @"CHChartConfigurationDidChangeNotification";
NSString * const CHChartAnimationDidCompleteNotification = @"CHChartAnimationDidCompleteNotification";

// User Info Keys
NSString * const CHChartDataKey = @"CHChartDataKey";
NSString * const CHChartSelectionKey = @"CHChartSelectionKey";
NSString * const CHChartConfigurationKey = @"CHChartConfigurationKey";
NSString * const CHChartAnimationKey = @"CHChartAnimationKey";
