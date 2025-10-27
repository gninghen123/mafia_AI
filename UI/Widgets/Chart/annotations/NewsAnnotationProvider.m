//
//  NewsAnnotationProvider.m
//  mafia_AI
//
//  Provides news annotations by detecting chart anomalies and fetching related news
//

#import "NewsAnnotationProvider.h"
#import "NewsChartBridge.h"
#import "RuntimeModels.h"

@implementation NewsAnnotationProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _newsChartBridge = [[NewsChartBridge alloc] init];
        _volumeSpikeThreshold = 2.0;
        _gapThreshold = 2.0;
        _gapVolumeThreshold = 1.2;
        _volumeAveragePeriod = 50;
    }
    return self;
}

#pragma mark - ChartAnnotationProvider Protocol

- (ChartAnnotationType)annotationType {
    return ChartAnnotationTypeNews;
}

- (NSString *)providerName {
    return @"News Annotations";
}

- (BOOL)isEnabled {
    return YES;
}

- (void)getAnnotationsForSymbol:(NSString *)symbol
                      startDate:(NSDate *)startDate
                        endDate:(NSDate *)endDate
                     completion:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError *error))completion {
    
    if (!self.chartData || self.chartData.count == 0) {
        NSLog(@"⚠️ NewsAnnotationProvider: No chart data available for anomaly detection");
        if (completion) completion(@[], nil);
        return;
    }
    
    NSLog(@"🔍 NewsAnnotationProvider: Detecting anomalies in %lu bars", (unsigned long)self.chartData.count);
    
    // 1. Rileva anomalie nel range di date
    NSArray<ChartAnomaly *> *anomalies = [self detectAnomaliesInChartDataBetween:startDate andEnd:endDate];
    
    if (anomalies.count == 0) {
        NSLog(@"ℹ️ NewsAnnotationProvider: No anomalies detected in date range");
        if (completion) completion(@[], nil);
        return;
    }
    
    NSLog(@"📊 NewsAnnotationProvider: Detected %lu anomalies", (unsigned long)anomalies.count);
    
    // 2. Per ogni anomalia, cerca news correlate
    NSMutableArray<ChartAnnotation *> *allAnnotations = [NSMutableArray array];
    __block NSInteger pending = anomalies.count;
    __block NSError *firstError = nil;
    
    for (ChartAnomaly *anomaly in anomalies) {
        [self.newsChartBridge findNewsForAnomaly:anomaly
                                      completion:^(NSArray<NewsWithRelevance *> *rankedNews, NSError *error) {
            
            if (error && !firstError) {
                firstError = error;
            }
            
            if (rankedNews.count > 0) {
                // Prendi la news più rilevante per questa anomalia
                NewsWithRelevance *topNews = rankedNews.firstObject;
                
                ChartAnnotation *annotation = [ChartAnnotation newsAnnotationWithNews:topNews.news
                                                                        relevanceScore:topNews.relevanceScore];
                annotation.symbol = symbol;
                
                // Aggiungi metadata sull'anomalia e tutte le news correlate
                NSMutableDictionary *metadata = [annotation.metadata mutableCopy];
                metadata[@"anomaly"] = anomaly;
                metadata[@"allNews"] = rankedNews;
                metadata[@"newsCount"] = @(rankedNews.count);
                annotation.metadata = [metadata copy];
                
                @synchronized(allAnnotations) {
                    [allAnnotations addObject:annotation];
                }
            }
            
            pending--;
            if (pending == 0) {
                NSLog(@"✅ NewsAnnotationProvider: Created %lu news annotations", (unsigned long)allAnnotations.count);
                if (completion) completion([allAnnotations copy], firstError);
            }
        }];
    }
}

#pragma mark - Anomaly Detection

- (NSArray<ChartAnomaly *> *)detectAnomaliesInChartDataBetween:(NSDate *)startDate andEnd:(NSDate *)endDate {
    
    NSMutableArray<ChartAnomaly *> *anomalies = [NSMutableArray array];
    
    // Filtra bars nel range di date
    NSArray<HistoricalBarModel *> *barsInRange = [self.chartData filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(HistoricalBarModel *bar, NSDictionary *bindings) {
        return [bar.date compare:startDate] != NSOrderedAscending &&
               [bar.date compare:endDate] != NSOrderedDescending;
    }]];
    
    if (barsInRange.count < self.volumeAveragePeriod + 1) {
        NSLog(@"⚠️ Not enough data for anomaly detection (need at least %ld bars)", (long)self.volumeAveragePeriod + 1);
        return @[];
    }
    
    // Calcola media mobile del volume
    for (NSInteger i = self.volumeAveragePeriod; i < barsInRange.count; i++) {
        HistoricalBarModel *currentBar = barsInRange[i];
        
        // Calcola average volume dei 50 giorni precedenti
        double volumeSum = 0;
        for (NSInteger j = i - self.volumeAveragePeriod; j < i; j++) {
            volumeSum += barsInRange[j].volume;
        }
        double avgVolume = volumeSum / self.volumeAveragePeriod;
        
        if (avgVolume == 0) continue;
        
        double volumeRatio = currentBar.volume / avgVolume;
        
        // Calcola price change %
        HistoricalBarModel *prevBar = barsInRange[i - 1];
        double priceChange = ((currentBar.open - prevBar.close) / prevBar.close) * 100.0;
        
        // Rileva anomalie
        BOOL isVolumeSpike = (volumeRatio >= self.volumeSpikeThreshold);
        BOOL isGapWithVolume = (fabs(priceChange) >= self.gapThreshold && volumeRatio >= self.gapVolumeThreshold);
        
        if (isVolumeSpike || isGapWithVolume) {
            ChartAnomaly *anomaly = [ChartAnomaly anomalyWithDate:currentBar.date
                                                           symbol:currentBar.symbol
                                               priceChangePercent:priceChange
                                                      volumeRatio:volumeRatio];
            
            [anomalies addObject:anomaly];
            
            NSLog(@"🎯 Anomaly detected: %@ on %@ | Price: %.2f%% | Volume: %.1fx",
                  currentBar.symbol,
                  currentBar.date,
                  priceChange,
                  volumeRatio);
        }
    }
    
    return [anomalies copy];
}

@end
