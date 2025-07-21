//
//  SymbolDataModels.m
//  TradingApp
//

#import "SymbolDataModels.h"

#pragma mark - SymbolData

@implementation SymbolData

@dynamic symbol;
@dynamic fullName;
@dynamic exchange;
@dynamic dateAdded;
@dynamic lastModified;
@dynamic tags;
@dynamic notes;
@dynamic alerts;
@dynamic savedNews;
@dynamic tradingConfig;
@dynamic customData;

- (void)addTagsObject:(TagData *)value {
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"tags" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"tags"] addObject:value];
    [self didChangeValueForKey:@"tags" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
}

- (void)removeTagsObject:(TagData *)value {
    NSSet *changedObjects = [[NSSet alloc] initWithObjects:&value count:1];
    [self willChangeValueForKey:@"tags" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"tags"] removeObject:value];
    [self didChangeValueForKey:@"tags" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
}

- (void)addTag:(TagData *)tag {
    [self addTagsObject:tag];
}

- (void)removeTag:(TagData *)tag {
    [self removeTagsObject:tag];
}

- (NSArray<NSString *> *)tagNames {
    NSMutableArray *names = [NSMutableArray array];
    for (TagData *tag in self.tags) {
        [names addObject:tag.name];
    }
    return [names sortedArrayUsingSelector:@selector(compare:)];
}

@end

#pragma mark - TagData

@implementation TagData

@dynamic name;
@dynamic colorHex;
@dynamic dateCreated;
@dynamic symbols;

@end

#pragma mark - NoteData

@implementation NoteData

@dynamic content;
@dynamic timestamp;
@dynamic author;
@dynamic symbol;

- (NSDictionary *)serialize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    if (self.content) dict[@"content"] = self.content;
    if (self.timestamp) dict[@"timestamp"] = self.timestamp;
    if (self.author) dict[@"author"] = self.author;
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    // Core Data objects devono essere creati con il context
    // Questo metodo sarà chiamato dopo la creazione dell'oggetto
    if (self) {
        self.content = dict[@"content"];
        self.timestamp = dict[@"timestamp"] ?: [NSDate date];
        self.author = dict[@"author"];
    }
    return self;
}

@end

#pragma mark - AlertData

@implementation AlertData

@dynamic alertId;
@dynamic type;
@dynamic status;
@dynamic conditions;
@dynamic message;
@dynamic dateCreated;
@dynamic dateTriggered;
@dynamic expirationDate;
@dynamic repeating;
@dynamic symbol;

- (BOOL)isActive {
    return self.status == AlertStatusActive;
}

- (BOOL)shouldCheckCondition {
    if (self.status != AlertStatusActive) return NO;
    
    if (self.expirationDate && [self.expirationDate timeIntervalSinceNow] < 0) {
        self.status = AlertStatusExpired;
        return NO;
    }
    
    return YES;
}

- (NSString *)formattedDescription {
    NSString *typeString = [self typeString];
    NSString *conditionString = [self conditionString];
    
    return [NSString stringWithFormat:@"%@ %@", typeString, conditionString];
}

- (NSString *)typeString {
    switch (self.type) {
        case AlertTypePriceAbove:
            return @"Price Above";
        case AlertTypePriceBelow:
            return @"Price Below";
        case AlertTypeVolumeAbove:
            return @"Volume Above";
        case AlertTypePercentChange:
            return @"% Change";
        case AlertTypeTechnicalIndicator:
            return @"Technical";
        case AlertTypePattern:
            return @"Pattern";
        case AlertTypeCustom:
        default:
            return @"Custom";
    }
}

- (NSString *)conditionString {
    if (!self.conditions) return @"";
    
    switch (self.type) {
        case AlertTypePriceAbove:
        case AlertTypePriceBelow: {
            NSNumber *price = self.conditions[@"price"];
            return price ? [NSString stringWithFormat:@"$%.2f", price.doubleValue] : @"";
        }
            
        case AlertTypeVolumeAbove: {
            NSNumber *volume = self.conditions[@"volume"];
            return volume ? [NSString stringWithFormat:@"%@", [self formatVolume:volume.integerValue]] : @"";
        }
            
        case AlertTypePercentChange: {
            NSNumber *percent = self.conditions[@"percent"];
            NSString *direction = self.conditions[@"direction"];
            return percent ? [NSString stringWithFormat:@"%@%.1f%%",
                            [direction isEqualToString:@"up"] ? @"+" : @"-",
                            percent.doubleValue] : @"";
        }
            
        default:
            return self.message ?: @"";
    }
}

- (NSString *)formatVolume:(NSInteger)volume {
    if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
    }
    return [NSString stringWithFormat:@"%ld", (long)volume];
}

- (NSDictionary *)serialize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"alertId"] = self.alertId;
    dict[@"type"] = @(self.type);
    dict[@"status"] = @(self.status);
    dict[@"conditions"] = self.conditions;
    if (self.message) dict[@"message"] = self.message;
    dict[@"dateCreated"] = self.dateCreated;
    if (self.dateTriggered) dict[@"dateTriggered"] = self.dateTriggered;
    if (self.expirationDate) dict[@"expirationDate"] = self.expirationDate;
    dict[@"repeating"] = @(self.repeating);
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self) {
        self.alertId = dict[@"alertId"];
        self.type = [dict[@"type"] integerValue];
        self.status = [dict[@"status"] integerValue];
        self.conditions = dict[@"conditions"];
        self.message = dict[@"message"];
        self.dateCreated = dict[@"dateCreated"];
        self.dateTriggered = dict[@"dateTriggered"];
        self.expirationDate = dict[@"expirationDate"];
        self.repeating = [dict[@"repeating"] boolValue];
    }
    return self;
}

@end

#pragma mark - NewsData

@implementation NewsData

@dynamic newsId;
@dynamic title;
@dynamic summary;
@dynamic url;
@dynamic source;
@dynamic publishDate;
@dynamic savedDate;
@dynamic sentiment;
@dynamic symbol;

- (NSDictionary *)serialize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"newsId"] = self.newsId;
    dict[@"title"] = self.title;
    if (self.summary) dict[@"summary"] = self.summary;
    if (self.url) dict[@"url"] = self.url;
    if (self.source) dict[@"source"] = self.source;
    dict[@"publishDate"] = self.publishDate;
    dict[@"savedDate"] = self.savedDate;
    if (self.sentiment) dict[@"sentiment"] = self.sentiment;
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self) {
        self.newsId = dict[@"newsId"];
        self.title = dict[@"title"];
        self.summary = dict[@"summary"];
        self.url = dict[@"url"];
        self.source = dict[@"source"];
        self.publishDate = dict[@"publishDate"];
        self.savedDate = dict[@"savedDate"] ?: [NSDate date];
        self.sentiment = dict[@"sentiment"];
    }
    return self;
}

@end

#pragma mark - TradingConfigData

@implementation TradingConfigData

@dynamic preferredDataSource;
@dynamic backupDataSource;
@dynamic defaultTimeframe;
@dynamic defaultChartType;
@dynamic defaultIndicators;
@dynamic defaultPositionSize;
@dynamic stopLossPercent;
@dynamic takeProfitPercent;
@dynamic useTrailingStop;
@dynamic maxPositionSize;
@dynamic maxDailyLoss;
@dynamic maxOpenPositions;
@dynamic symbol;

- (NSDictionary *)serialize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    // Data sources
    if (self.preferredDataSource) dict[@"preferredDataSource"] = self.preferredDataSource;
    if (self.backupDataSource) dict[@"backupDataSource"] = self.backupDataSource;
    
    // Chart settings
    if (self.defaultTimeframe) dict[@"defaultTimeframe"] = self.defaultTimeframe;
    if (self.defaultChartType) dict[@"defaultChartType"] = self.defaultChartType;
    if (self.defaultIndicators) dict[@"defaultIndicators"] = self.defaultIndicators;
    
    // Trading preferences
    dict[@"defaultPositionSize"] = @(self.defaultPositionSize);
    dict[@"stopLossPercent"] = @(self.stopLossPercent);
    dict[@"takeProfitPercent"] = @(self.takeProfitPercent);
    dict[@"useTrailingStop"] = @(self.useTrailingStop);
    
    // Risk management
    dict[@"maxPositionSize"] = @(self.maxPositionSize);
    dict[@"maxDailyLoss"] = @(self.maxDailyLoss);
    dict[@"maxOpenPositions"] = @(self.maxOpenPositions);
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    if (self) {
        // Data sources
        self.preferredDataSource = dict[@"preferredDataSource"];
        self.backupDataSource = dict[@"backupDataSource"];
        
        // Chart settings
        self.defaultTimeframe = dict[@"defaultTimeframe"];
        self.defaultChartType = dict[@"defaultChartType"];
        self.defaultIndicators = dict[@"defaultIndicators"];
        
        // Trading preferences
        self.defaultPositionSize = [dict[@"defaultPositionSize"] doubleValue];
        self.stopLossPercent = [dict[@"stopLossPercent"] doubleValue];
        self.takeProfitPercent = [dict[@"takeProfitPercent"] doubleValue];
        self.useTrailingStop = [dict[@"useTrailingStop"] boolValue];
        
        // Risk management
        self.maxPositionSize = [dict[@"maxPositionSize"] doubleValue];
        self.maxDailyLoss = [dict[@"maxDailyLoss"] doubleValue];
        self.maxOpenPositions = [dict[@"maxOpenPositions"] integerValue];
    }
    return self;
}

@end

#pragma mark - Helper Classes

@implementation CustomDataObject

- (NSDictionary *)serialize {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"dataType"] = self.dataType;
    dict[@"timestamp"] = self.timestamp;
    dict[@"data"] = self.data;
    
    return dict;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict {
    self = [super init];
    if (self) {
        self.dataType = dict[@"dataType"];
        self.timestamp = dict[@"timestamp"];
        self.data = dict[@"data"];
    }
    return self;
}

@end

#pragma mark - SymbolDataQuery

@implementation SymbolDataQuery

- (instancetype)init {
    self = [super init];
    if (self) {
        _predicates = [NSMutableArray array];
        _sortDescriptors = @[];
        _limit = 0;
    }
    return self;
}

+ (instancetype)query {
    return [[self alloc] init];
}

- (SymbolDataQuery *)withTag:(NSString *)tag {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ANY tags.name == %@", tag.lowercaseString];
    [self.predicates addObject:predicate];
    return self;
}

- (SymbolDataQuery *)withTags:(NSArray<NSString *> *)tags {
    NSMutableArray *tagPredicates = [NSMutableArray array];
    for (NSString *tag in tags) {
        [tagPredicates addObject:[NSPredicate predicateWithFormat:@"ANY tags.name == %@", tag.lowercaseString]];
    }
    NSPredicate *orPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:tagPredicates];
    [self.predicates addObject:orPredicate];
    return self;
}

- (SymbolDataQuery *)withActiveAlerts {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"ANY alerts.status == %d", AlertStatusActive];
    [self.predicates addObject:predicate];
    return self;
}

- (SymbolDataQuery *)modifiedSince:(NSDate *)date {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"lastModified >= %@", date];
    [self.predicates addObject:predicate];
    return self;
}

- (SymbolDataQuery *)sortedBySymbol {
    self.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"symbol" ascending:YES]];
    return self;
}

- (SymbolDataQuery *)sortedByLastModified {
    self.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastModified" ascending:NO]];
    return self;
}

- (SymbolDataQuery *)limitTo:(NSInteger)count {
    self.limit = count;
    return self;
}

- (NSPredicate *)buildPredicate {
    if (self.predicates.count == 0) {
        return [NSPredicate predicateWithValue:YES]; // Tutti i record
    } else if (self.predicates.count == 1) {
        return self.predicates.firstObject;
    } else {
        return [NSCompoundPredicate andPredicateWithSubpredicates:self.predicates];
    }
}
@end

@implementation WatchlistDataModel

@dynamic name;
@dynamic watchlistId;
@dynamic dateCreated;
@dynamic lastModified;
@dynamic isDynamic;
@dynamic dynamicTag;
@dynamic symbols;
@dynamic sortOrder;

- (NSArray<NSString *> *)symbolNames {
    NSMutableArray *names = [NSMutableArray array];
    for (SymbolData *symbol in self.symbols) {
        [names addObject:symbol.symbol];
    }
    return [names sortedArrayUsingSelector:@selector(compare:)];
}

- (void)addSymbol:(NSString *)symbolName {
    if (!symbolName) return;
    
    SymbolData *symbolData = [[SymbolData sharedHub] dataForSymbol:symbolName];
    if (symbolData) {
        NSMutableSet *mutableSymbols = [self.symbols mutableCopy];
        [mutableSymbols addObject:symbolData];
        self.symbols = mutableSymbols;
        self.lastModified = [NSDate date];
    }
}

- (void)removeSymbol:(NSString *)symbolName {
    if (!symbolName) return;
    
    for (SymbolData *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:symbolName]) {
            NSMutableSet *mutableSymbols = [self.symbols mutableCopy];
            [mutableSymbols removeObject:symbol];
            self.symbols = mutableSymbols;
            self.lastModified = [NSDate date];
            break;
        }
    }
}

- (BOOL)containsSymbol:(NSString *)symbolName {
    for (SymbolData *symbol in self.symbols) {
        if ([symbol.symbol isEqualToString:symbolName]) {
            return YES;
        }
    }
    return NO;
}


@end
