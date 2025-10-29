//
//  VolumeSpikeIndicator.m
//  TradingApp
//

#import "VolumeSpikeIndicator.h"

@implementation VolumeSpikeIndicator

- (CGFloat)calculateScoreForSymbol:(NSString *)symbol
                          withData:(NSArray<HistoricalBarModel *> *)bars
                        parameters:(NSDictionary *)params {
    
    NSInteger volumeMAPeriod = [params[@"volumeMAPeriod"] integerValue] ?: 20;
    
    if (!bars || bars.count < volumeMAPeriod) {
        NSLog(@"⚠️ VolumeSpike: Insufficient data for %@ (need %ld bars, have %lu)",
              symbol, (long)volumeMAPeriod, (unsigned long)bars.count);
        return 0.0;
    }
    
    // Calculate average volume for last N bars
    CGFloat volumeSum = 0.0;
    NSInteger startIndex = bars.count - volumeMAPeriod;
    
    for (NSInteger i = startIndex; i < bars.count; i++) {
        volumeSum += bars[i].volume;
    }
    
    CGFloat avgVolume = volumeSum / volumeMAPeriod;
    
    // Get current volume
    HistoricalBarModel *latestBar = bars.lastObject;
    CGFloat currentVolume = latestBar.volume;
    
    // Calculate ratio
    CGFloat ratio = (avgVolume > 0) ? (currentVolume / avgVolume) : 0.0;
    
    NSLog(@"📊 VolumeSpike %@: current=%.0f avg=%.0f ratio=%.2fx",
          symbol, currentVolume, avgVolume, ratio);
    
    // Graduated scoring
    CGFloat score;
    if (ratio >= 3.0) {
        score = 100.0;
    } else if (ratio >= 2.5) {
        score = 85.0;
    } else if (ratio >= 2.0) {
        score = 70.0;
    } else if (ratio >= 1.5) {
        score = 50.0;
    } else if (ratio >= 1.0) {
        score = 25.0;
    } else if (ratio >= 0.5) {
        score = 0.0;
    } else {
        score = -50.0; // Dead volume
    }
    
    NSLog(@"✅ VolumeSpike %@: ratio=%.2fx → score=%.1f", symbol, ratio, score);
    
    return score;
}

- (NSString *)indicatorType {
    return @"VolumeSpike";
}

- (NSString *)displayName {
    return @"Volume Spike";
}

- (NSInteger)minimumBarsRequired {
    return 20; // Default volume MA period
}

- (NSDictionary *)defaultParameters {
    return @{
        @"volumeMAPeriod": @(20),
        @"baseCoefficient": @(1.5)
    };
}

- (NSString *)indicatorDescription {
    return @"Measures volume relative to average, identifying unusual activity. Higher ratios indicate strong interest.";
}

@end
