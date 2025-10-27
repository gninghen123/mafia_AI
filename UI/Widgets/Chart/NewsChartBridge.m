//
//  NewsChartBridge.m
//  mafia_AI
//
//  Business logic for news-anomaly correlation
//

#import "NewsChartBridge.h"
#import "DataHub.h"
#import "DataHub+News.h"
#import "RuntimeModels.h"

@implementation NewsWithRelevance
@end

@implementation NewsChartBridge

- (instancetype)init {
    self = [super init];
    if (self) {
        _hoursBeforeAnomaly = 36;  // 1.5 giorni prima
        _hoursAfterAnomaly = 24;   // 1 giorno dopo
        _minimumRelevanceScore = 50.0;
    }
    return self;
}

#pragma mark - Main Methods

- (void)findNewsForAnomaly:(ChartAnomaly *)anomaly
                completion:(void(^)(NSArray<NewsWithRelevance *> *rankedNews, NSError *error))completion {
    
    if (!anomaly || !anomaly.symbol || !anomaly.date) {
        NSError *error = [NSError errorWithDomain:@"NewsChartBridge"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid anomaly data"}];
        if (completion) completion(@[], error);
        return;
    }
    
    NSLog(@"🔍 NewsChartBridge: Searching news for anomaly on %@ at %@", anomaly.symbol, anomaly.date);
    
    // 1. Fetch news nel range temporale
    DataHub *hub = [DataHub shared];
    
    [hub getNewsAroundDate:anomaly.date
                 forSymbol:anomaly.symbol
              hoursBefore:self.hoursBeforeAnomaly
               hoursAfter:self.hoursAfterAnomaly
             forceRefresh:NO
               completion:^(NSArray<NewsModel *> *news, BOOL isFresh, NSError *error) {
        
        if (error) {
            NSLog(@"❌ NewsChartBridge: Failed to fetch news: %@", error.localizedDescription);
            if (completion) completion(@[], error);
            return;
        }
        
        NSLog(@"📰 NewsChartBridge: Received %lu news items for analysis", (unsigned long)news.count);
        
        // 2. Calcola relevance score per ogni news
        NSMutableArray<NewsWithRelevance *> *scoredNews = [NSMutableArray array];
        
        for (NewsModel *newsItem in news) {
            double score = [self calculateRelevanceScore:newsItem forAnomaly:anomaly];
            
            // Filtra per minimum score
            if (score >= self.minimumRelevanceScore) {
                NewsWithRelevance *item = [[NewsWithRelevance alloc] init];
                item.news = newsItem;
                item.relevanceScore = score;
                [scoredNews addObject:item];
            }
        }
        
        // 3. Ordina per score decrescente (più rilevanti prima)
        [scoredNews sortUsingComparator:^NSComparisonResult(NewsWithRelevance *a, NewsWithRelevance *b) {
            if (a.relevanceScore > b.relevanceScore) return NSOrderedAscending;
            if (a.relevanceScore < b.relevanceScore) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
        NSLog(@"✅ NewsChartBridge: Found %lu relevant news items (score >= %.0f)",
              (unsigned long)scoredNews.count, self.minimumRelevanceScore);
        
        if (scoredNews.count > 0) {
            NSLog(@"   Top news: '%@' (score: %.0f)",
                  scoredNews.firstObject.news.headline,
                  scoredNews.firstObject.relevanceScore);
        }
        
        if (completion) completion([scoredNews copy], nil);
    }];
}

- (double)calculateRelevanceScore:(NewsModel *)news
                      forAnomaly:(ChartAnomaly *)anomaly {
    
    double score = 0.0;
    
    // 1. TEMPORAL PROXIMITY (0-30 punti)
    // News più vicine temporalmente all'anomalia hanno score maggiore
    NSTimeInterval timeDiff = fabs([news.publishedDate timeIntervalSinceDate:anomaly.date]);
    double hoursAway = timeDiff / 3600.0;
    
    if (hoursAway < 6) {
        score += 30;  // Entro 6 ore: massimo punteggio
    } else if (hoursAway < 24) {
        score += 25 - (hoursAway - 6) / 18.0 * 5;  // 6-24h: 25-20 punti
    } else {
        score += 20 - (hoursAway - 24) / 36.0 * 20;  // 24-60h: 20-0 punti
    }
    
    // 2. KEYWORD MATCHING (0-40 punti)
    NSString *headlineLower = news.headline.lowercaseString;
    NSString *symbolLower = anomaly.symbol.lowercaseString;
    
    // Ticker symbol mention (15 punti)
    if ([headlineLower containsString:symbolLower]) {
        score += 15;
    }
    
    // Impact keywords (25 punti totali possibili)
    NSDictionary *impactKeywords = @{
        @"earnings": @10,
        @"revenue": @8,
        @"profit": @8,
        @"beat": @7,
        @"miss": @7,
        @"guidance": @6,
        @"fda": @10,
        @"approval": @10,
        @"acquisition": @9,
        @"merger": @9,
        @"partnership": @7,
        @"deal": @6,
        @"lawsuit": @8,
        @"investigation": @7,
        @"recall": @9,
        @"bankruptcy": @10,
        @"ceo": @5,
        @"resign": @7,
        @"layoff": @6,
        @"dividend": @5,
        @"split": @6
    };
    
    double keywordScore = 0;
    for (NSString *keyword in impactKeywords) {
        if ([headlineLower containsString:keyword]) {
            keywordScore += [impactKeywords[keyword] doubleValue];
        }
    }
    score += MIN(keywordScore, 25);  // Cap at 25
    
    // 3. SOURCE AUTHORITY (0-20 punti)
    NSDictionary *sourceWeights = @{
        @"bloomberg": @20,
        @"reuters": @18,
        @"wsj": @18,
        @"wall street journal": @18,
        @"cnbc": @15,
        @"financial times": @17,
        @"marketwatch": @14,
        @"seeking alpha": @12,
        @"yahoo finance": @10,
        @"benzinga": @10
    };
    
    NSString *sourceLower = news.source.lowercaseString;
    double sourceScore = 5;  // Default for unknown sources
    
    for (NSString *source in sourceWeights) {
        if ([sourceLower containsString:source]) {
            sourceScore = [sourceWeights[source] doubleValue];
            break;
        }
    }
    score += sourceScore;
    
    // 4. SENTIMENT ALIGNMENT (0-10 punti)
    // Se sentiment della news allinea con direzione dell'anomalia
    BOOL priceUp = (anomaly.priceChangePercent > 0);
    
    // sentiment: -1 negative, 0 neutral, 1 positive
    if (news.sentiment == 1 && priceUp) {  // Positive sentiment + price up
        score += 10;
    } else if (news.sentiment == -1 && !priceUp) {  // Negative sentiment + price down
        score += 10;
    } else if (news.sentiment == 0) {  // Neutral
        score += 5;  // Neutrale = mezzo punteggio
    }
    
    // Score finale deve essere 0-100
    score = MAX(0, MIN(100, score));
    
    return score;
}

@end
