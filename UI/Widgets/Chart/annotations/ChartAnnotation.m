//
//  ChartAnnotation.m
//  mafia_AI
//
//  Base model for all chart annotations
//

#import "ChartAnnotation.h"
#import "RuntimeModels.h"

@implementation ChartAnnotation

- (instancetype)init {
    self = [super init];
    if (self) {
        _annotationID = [[NSUUID UUID] UUIDString];
        _relevanceScore = 50.0;
        _priority = ChartAnnotationPriorityMedium;
        _shouldPulse = NO;
        _icon = @"📌";
        _color = [NSColor systemGrayColor];
    }
    return self;
}

#pragma mark - Factory Methods

+ (instancetype)newsAnnotationWithNews:(NewsModel *)news
                        relevanceScore:(double)score {
    ChartAnnotation *annotation = [[ChartAnnotation alloc] init];
    annotation.type = ChartAnnotationTypeNews;
    annotation.date = news.publishedDate;
    annotation.symbol = news.symbol ?: @"";
    annotation.title = news.headline;
    annotation.content = news.summary ?: news.headline;
    annotation.relevanceScore = score;
    
    // Visual config based on relevance
    if (score >= 80) {
        annotation.icon = @"⭐";
        annotation.color = [NSColor systemRedColor];
        annotation.priority = ChartAnnotationPriorityHigh;
    } else if (score >= 60) {
        annotation.icon = @"📰";
        annotation.color = [NSColor systemOrangeColor];
        annotation.priority = ChartAnnotationPriorityMedium;
    } else {
        annotation.icon = @"ℹ️";
        annotation.color = [NSColor systemBlueColor];
        annotation.priority = ChartAnnotationPriorityLow;
    }
    
    // Store original news in metadata
    annotation.metadata = @{
        @"newsModel": news,
        @"source": news.source ?: @"Unknown",
        @"url": news.url ?: @""
    };
    
    return annotation;
}

+ (instancetype)noteAnnotationWithTitle:(NSString *)title
                                content:(NSString *)content
                                   date:(NSDate *)date {
    ChartAnnotation *annotation = [[ChartAnnotation alloc] init];
    annotation.type = ChartAnnotationTypeNote;
    annotation.date = date;
    annotation.title = title;
    annotation.content = content;
    annotation.icon = @"📝";
    annotation.color = [NSColor systemYellowColor];
    annotation.priority = ChartAnnotationPriorityMedium;
    annotation.relevanceScore = 100.0; // User notes always relevant
    
    return annotation;
}

+ (instancetype)userMessageAnnotationWithMessage:(NSString *)message
                                        fromUser:(NSString *)username
                                            date:(NSDate *)date {
    ChartAnnotation *annotation = [[ChartAnnotation alloc] init];
    annotation.type = ChartAnnotationTypeUserMessage;
    annotation.date = date;
    annotation.title = [NSString stringWithFormat:@"Message from %@", username];
    annotation.content = message;
    annotation.icon = @"💬";
    annotation.color = [NSColor systemBlueColor];
    annotation.priority = ChartAnnotationPriorityMedium;
    annotation.relevanceScore = 90.0;
    
    annotation.metadata = @{
        @"username": username,
        @"messageID": [[NSUUID UUID] UUIDString]
    };
    
    return annotation;
}

+ (instancetype)alertAnnotationWithTitle:(NSString *)title
                              alertType:(NSString *)alertType
                                   date:(NSDate *)date {
    ChartAnnotation *annotation = [[ChartAnnotation alloc] init];
    annotation.type = ChartAnnotationTypeAlert;
    annotation.date = date;
    annotation.title = title;
    annotation.content = [NSString stringWithFormat:@"Alert: %@", alertType];
    annotation.icon = @"⚠️";
    annotation.color = [NSColor systemRedColor];
    annotation.priority = ChartAnnotationPriorityCritical;
    annotation.shouldPulse = YES;
    annotation.relevanceScore = 100.0;
    
    annotation.metadata = @{
        @"alertType": alertType
    };
    
    return annotation;
}

+ (instancetype)eventAnnotationWithTitle:(NSString *)title
                                    icon:(NSString *)icon
                                   color:(NSColor *)color
                                    date:(NSDate *)date {
    ChartAnnotation *annotation = [[ChartAnnotation alloc] init];
    annotation.type = ChartAnnotationTypeEvent;
    annotation.date = date;
    annotation.title = title;
    annotation.icon = icon ?: @"📅";
    annotation.color = color ?: [NSColor systemPurpleColor];
    annotation.priority = ChartAnnotationPriorityMedium;
    annotation.relevanceScore = 75.0;
    
    return annotation;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ChartAnnotation: %@ | Type: %ld | Date: %@ | Score: %.0f | Title: %@>",
            self.annotationID,
            (long)self.type,
            self.date,
            self.relevanceScore,
            self.title];
}

@end

#pragma mark - Chart Anomaly Implementation

@implementation ChartAnomaly

+ (instancetype)anomalyWithDate:(NSDate *)date
                         symbol:(NSString *)symbol
              priceChangePercent:(double)priceChange
                    volumeRatio:(double)volumeRatio {
    ChartAnomaly *anomaly = [[ChartAnomaly alloc] init];
    anomaly.date = date;
    anomaly.symbol = symbol;
    anomaly.priceChangePercent = priceChange;
    anomaly.volumeRatio = volumeRatio;
    anomaly.isVolumeSpike = (volumeRatio >= 2.0);
    anomaly.isGap = (fabs(priceChange) >= 2.0 && volumeRatio >= 1.2);
    
    return anomaly;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<ChartAnomaly: %@ | %@ | Price: %.2f%% | Volume: %.1fx | Gap: %@ | Spike: %@>",
            self.symbol,
            self.date,
            self.priceChangePercent,
            self.volumeRatio,
            self.isGap ? @"YES" : @"NO",
            self.isVolumeSpike ? @"YES" : @"NO"];
}

@end
