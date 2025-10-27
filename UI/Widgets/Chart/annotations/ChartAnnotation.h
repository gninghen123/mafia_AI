//
//  ChartAnnotation.h
//  mafia_AI
//
//  Base model for all chart annotations (news, notes, messages, alerts, events)
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class NewsModel;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ChartAnnotationType) {
    ChartAnnotationTypeNews = 0,
    ChartAnnotationTypeNote = 1,
    ChartAnnotationTypeUserMessage = 2,
    ChartAnnotationTypeAlert = 3,
    ChartAnnotationTypeEvent = 4,
    ChartAnnotationTypeCustom = 99
};

typedef NS_ENUM(NSInteger, ChartAnnotationPriority) {
    ChartAnnotationPriorityLow = 0,
    ChartAnnotationPriorityMedium = 1,
    ChartAnnotationPriorityHigh = 2,
    ChartAnnotationPriorityCritical = 3
};

@interface ChartAnnotation : NSObject

#pragma mark - Core Properties

/// Unique identifier
@property (nonatomic, strong) NSString *annotationID;

/// Type of annotation
@property (nonatomic, assign) ChartAnnotationType type;

/// Date/time when annotation should appear on chart
@property (nonatomic, strong) NSDate *date;

/// Symbol this annotation is associated with
@property (nonatomic, strong) NSString *symbol;

/// Short title (displayed in marker)
@property (nonatomic, strong) NSString *title;

/// Full content (displayed in modal)
@property (nonatomic, strong, nullable) NSString *content;

/// Relevance score (0-100) - used for filtering
@property (nonatomic, assign) double relevanceScore;

#pragma mark - Visual Properties

/// Icon to display (emoji or SF Symbol name)
@property (nonatomic, strong) NSString *icon;

/// Badge color
@property (nonatomic, strong) NSColor *color;

/// Priority level
@property (nonatomic, assign) ChartAnnotationPriority priority;

/// Should pulse/animate
@property (nonatomic, assign) BOOL shouldPulse;

#pragma mark - Extended Metadata

/// Generic metadata dictionary (extensible)
@property (nonatomic, strong, nullable) NSDictionary *metadata;

#pragma mark - Factory Methods

/**
 * Creates a news annotation from a NewsModel
 */
+ (instancetype)newsAnnotationWithNews:(NewsModel *)news
                        relevanceScore:(double)score;

/**
 * Creates a personal note annotation
 */
+ (instancetype)noteAnnotationWithTitle:(NSString *)title
                                content:(NSString *)content
                                   date:(NSDate *)date;

/**
 * Creates a user message annotation
 */
+ (instancetype)userMessageAnnotationWithMessage:(NSString *)message
                                        fromUser:(NSString *)username
                                            date:(NSDate *)date;

/**
 * Creates an alert annotation
 */
+ (instancetype)alertAnnotationWithTitle:(NSString *)title
                              alertType:(NSString *)alertType
                                   date:(NSDate *)date;

/**
 * Creates a custom event annotation
 */
+ (instancetype)eventAnnotationWithTitle:(NSString *)title
                                    icon:(NSString *)icon
                                   color:(NSColor *)color
                                    date:(NSDate *)date;

@end

#pragma mark - Chart Anomaly Model

/**
 * Represents a detected anomaly in chart data (volume spike, gap, etc.)
 */
@interface ChartAnomaly : NSObject

@property (nonatomic, strong) NSDate *date;
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, assign) double priceChangePercent;
@property (nonatomic, assign) double volumeRatio;  // volume / average volume
@property (nonatomic, assign) BOOL isGap;
@property (nonatomic, assign) BOOL isVolumeSpike;

+ (instancetype)anomalyWithDate:(NSDate *)date
                         symbol:(NSString *)symbol
              priceChangePercent:(double)priceChange
                    volumeRatio:(double)volumeRatio;

@end

NS_ASSUME_NONNULL_END
