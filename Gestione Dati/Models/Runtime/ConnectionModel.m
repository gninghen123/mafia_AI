//
//  ConnectionModel.m
//  mafia_AI
//

#import "ConnectionModel.h"
#import <Cocoa/Cocoa.h>

@implementation ConnectionModel

#pragma mark - Initializers

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectionID = [[NSUUID UUID] UUIDString];
        _title = @"";
        _symbols = @[];
        _targetSymbols = @[];
        _tags = @[];
        _connectionType = StockConnectionTypeNews;
        _bidirectional = NO;
        _creationDate = [NSDate date];
        _lastModified = [NSDate date];
        _isActive = YES;
        _summarySource = ConnectionSummarySourceNone;
        _initialStrength = 1.0;
        _currentStrength = 1.0;
        _decayRate = 0.0;
        _minimumStrength = 0.1;
        _autoDelete = NO;
        _lastStrengthUpdate = [NSDate date];
    }
    return self;
}

- (instancetype)initWithSymbols:(NSArray<NSString *> *)symbols
                            type:(StockConnectionType)type
                           title:(NSString *)title {
    self = [self init];
    if (self) {
        _symbols = [symbols copy];
        _connectionType = type;
        _title = [title copy];
        _bidirectional = YES;  // Default per backwards compatibility
    }
    return self;
}

- (instancetype)initDirectionalFromSymbol:(NSString *)sourceSymbol
                                toSymbols:(NSArray<NSString *> *)targetSymbols
                                     type:(StockConnectionType)type
                                    title:(NSString *)title {
    self = [self init];
    if (self) {
        _sourceSymbol = [sourceSymbol copy];
        _targetSymbols = [targetSymbols copy];
        _connectionType = type;
        _title = [title copy];
        _bidirectional = NO;
        
        // Crea anche l'array legacy symbols per compatibilità
        NSMutableArray *allSymbols = [NSMutableArray arrayWithObject:sourceSymbol];
        [allSymbols addObjectsFromArray:targetSymbols];
        _symbols = [allSymbols copy];
    }
    return self;
}

- (instancetype)initBidirectionalWithSymbols:(NSArray<NSString *> *)symbols
                                         type:(StockConnectionType)type
                                        title:(NSString *)title {
    self = [self init];
    if (self) {
        _symbols = [symbols copy];
        _connectionType = type;
        _title = [title copy];
        _bidirectional = YES;
        _targetSymbols = [symbols copy];
    }
    return self;
}

#pragma mark - Symbol Utilities

- (NSArray<NSString *> *)allInvolvedSymbols {
    if (self.bidirectional || !self.sourceSymbol) {
        return self.symbols;
    } else {
        NSMutableArray *allSymbols = [NSMutableArray arrayWithObject:self.sourceSymbol];
        [allSymbols addObjectsFromArray:self.targetSymbols];
        return [allSymbols copy];
    }
}

- (BOOL)involvesSymbol:(NSString *)symbol {
    return [[self allInvolvedSymbols] containsObject:symbol];
}

- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol {
    NSMutableArray *related = [NSMutableArray array];
    NSArray *allSymbols = [self allInvolvedSymbols];
    
    if (![allSymbols containsObject:symbol]) {
        return @[];  // Symbol not involved in this connection
    }
    
    if (self.bidirectional) {
        // In connessioni bidirezionali, tutti i simboli sono correlati tra loro
        for (NSString *otherSymbol in allSymbols) {
            if (![otherSymbol isEqualToString:symbol]) {
                [related addObject:otherSymbol];
            }
        }
    } else {
        // In connessioni direzionali
        if ([symbol isEqualToString:self.sourceSymbol]) {
            // Se è il simbolo sorgente, tutti i target sono correlati
            [related addObjectsFromArray:self.targetSymbols];
        } else {
            // Se è un target, è correlato alla sorgente e agli altri target
            [related addObject:self.sourceSymbol];
            for (NSString *target in self.targetSymbols) {
                if (![target isEqualToString:symbol]) {
                    [related addObject:target];
                }
            }
        }
    }
    
    return [related copy];
}

#pragma mark - Summary Methods

- (NSString *)effectiveSummary {
    if (self.manualSummary.length > 0) {
        return self.manualSummary;
    }
    if (self.originalSummary.length > 0) {
        return self.originalSummary;
    }
    if (self.connectionDescription.length > 0) {
        return self.connectionDescription;
    }
    return @"No summary available";
}

- (BOOL)hasSummary {
    return (self.manualSummary.length > 0 ||
            self.originalSummary.length > 0 ||
            self.connectionDescription.length > 0);
}

- (void)setAISummary:(NSString *)summary {
    // Safety checks
    if (!summary) {
        _originalSummary = nil;
        return;
    }
    
    // Ensure we're on main thread for property updates
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setAISummary:summary];
        });
        return;
    }
    
    // Copy the string to avoid memory issues
    _originalSummary = [summary copy];
    
    // Update summary source safely
    if (self.summarySource == ConnectionSummarySourceNone) {
        _summarySource = ConnectionSummarySourceAI;
    } else if (self.summarySource == ConnectionSummarySourceManual) {
        _summarySource = ConnectionSummarySourceBoth;
    }
    
    // Update last modified date
    _lastModified = [NSDate date];
    
    NSLog(@"ConnectionModel: Set AI summary (%lu chars)", (unsigned long)summary.length);
}
- (void)setManualSummary:(NSString *)summary {
    // Safety checks
    if (!summary) {
        _manualSummary = nil;
        return;
    }
    
    // Ensure we're on main thread for property updates
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setManualSummary:summary];
        });
        return;
    }
    
    // Copy the string to avoid memory issues
    _manualSummary = [summary copy];
    
    // Update summary source safely
    if (self.summarySource == ConnectionSummarySourceNone) {
        _summarySource = ConnectionSummarySourceManual;
    } else if (self.summarySource == ConnectionSummarySourceAI) {
        _summarySource = ConnectionSummarySourceBoth;
    }
    
    // Update last modified date
    _lastModified = [NSDate date];
    
    NSLog(@"ConnectionModel: Set manual summary (%lu chars)", (unsigned long)summary.length);
}

#pragma mark - Strength Calculation

- (void)updateCurrentStrength {
    if (self.decayRate == 0.0 || !self.strengthHorizon) {
        self.currentStrength = self.initialStrength;
        self.lastStrengthUpdate = [NSDate date];
        return;
    }
    
    self.currentStrength = [self calculateStrengthForDate:[NSDate date]];
    self.lastStrengthUpdate = [NSDate date];
}

- (double)calculateStrengthForDate:(NSDate *)date {
    if (self.decayRate == 0.0 || !self.strengthHorizon) {
        return self.initialStrength;
    }
    
    NSTimeInterval secondsSinceCreation = [date timeIntervalSinceDate:self.creationDate];
    NSTimeInterval totalSecondsToHorizon = [self.strengthHorizon timeIntervalSinceDate:self.creationDate];
    
    if (totalSecondsToHorizon <= 0) {
        return self.minimumStrength;
    }
    
    double progressRatio = secondsSinceCreation / totalSecondsToHorizon;
    if (progressRatio >= 1.0) {
        return self.minimumStrength;
    }
    
    // Linear decay for now (can add exponential later)
    double strengthRange = self.initialStrength - self.minimumStrength;
    double decayedAmount = strengthRange * progressRatio * self.decayRate;
    
    return MAX(self.minimumStrength, self.initialStrength - decayedAmount);
}

- (BOOL)shouldAutoDelete {
    if (!self.autoDelete) return NO;
    
    [self updateCurrentStrength];
    return self.currentStrength <= self.minimumStrength;
}

- (NSInteger)daysUntilMinimumStrength {
    if (self.decayRate == 0.0 || !self.strengthHorizon) {
        return NSIntegerMax;  // Never decays
    }
    
    NSTimeInterval secondsRemaining = [self.strengthHorizon timeIntervalSinceDate:[NSDate date]];
    if (secondsRemaining <= 0) {
        return 0;
    }
    
    return (NSInteger)(secondsRemaining / (24 * 60 * 60));
}

#pragma mark - Display Methods

- (NSString *)typeDisplayString {
    return StringFromConnectionType(self.connectionType);
}

- (NSString *)strengthDisplayString {
    [self updateCurrentStrength];
    return [NSString stringWithFormat:@"%.1f%%", self.currentStrength * 100];
}

- (NSColor *)typeColor {
    return ColorForConnectionType(self.connectionType);
}

- (NSString *)typeIcon {
    return IconForConnectionType(self.connectionType);
}

#pragma mark - Serialization

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    
    dict[@"connectionID"] = self.connectionID;
    dict[@"title"] = self.title ?: @"";
    dict[@"connectionDescription"] = self.connectionDescription ?: @"";
    dict[@"symbols"] = self.symbols ?: @[];
    dict[@"sourceSymbol"] = self.sourceSymbol ?: @"";
    dict[@"targetSymbols"] = self.targetSymbols ?: @[];
    dict[@"bidirectional"] = @(self.bidirectional);
    dict[@"connectionType"] = @(self.connectionType);
    dict[@"source"] = self.source ?: @"";
    dict[@"url"] = self.url ?: @"";
    dict[@"notes"] = self.notes ?: @"";
    dict[@"tags"] = self.tags ?: @[];
    dict[@"creationDate"] = self.creationDate;
    dict[@"lastModified"] = self.lastModified;
    dict[@"isActive"] = @(self.isActive);
    dict[@"originalSummary"] = self.originalSummary ?: @"";
    dict[@"manualSummary"] = self.manualSummary ?: @"";
    dict[@"summarySource"] = @(self.summarySource);
    dict[@"initialStrength"] = @(self.initialStrength);
    dict[@"currentStrength"] = @(self.currentStrength);
    dict[@"decayRate"] = @(self.decayRate);
    dict[@"minimumStrength"] = @(self.minimumStrength);
    dict[@"strengthHorizon"] = self.strengthHorizon;
    dict[@"autoDelete"] = @(self.autoDelete);
    dict[@"lastStrengthUpdate"] = self.lastStrengthUpdate;
    
    return [dict copy];
}

- (void)updateFromDictionary:(NSDictionary *)dict {
    self.connectionID = dict[@"connectionID"] ?: [[NSUUID UUID] UUIDString];
    self.title = dict[@"title"] ?: @"";
    self.connectionDescription = dict[@"connectionDescription"];
    self.symbols = dict[@"symbols"] ?: @[];
    self.sourceSymbol = dict[@"sourceSymbol"];
    self.targetSymbols = dict[@"targetSymbols"] ?: @[];
    self.bidirectional = [dict[@"bidirectional"] boolValue];
    self.connectionType = [dict[@"connectionType"] integerValue];
    self.source = dict[@"source"];
    self.url = dict[@"url"];
    self.notes = dict[@"notes"];
    self.tags = dict[@"tags"] ?: @[];
    self.creationDate = dict[@"creationDate"] ?: [NSDate date];
    self.lastModified = dict[@"lastModified"] ?: [NSDate date];
    self.isActive = dict[@"isActive"] ? [dict[@"isActive"] boolValue] : YES;
    self.originalSummary = dict[@"originalSummary"];
    self.manualSummary = dict[@"manualSummary"];
    self.summarySource = [dict[@"summarySource"] integerValue];
    self.initialStrength = dict[@"initialStrength"] ? [dict[@"initialStrength"] doubleValue] : 1.0;
    self.currentStrength = dict[@"currentStrength"] ? [dict[@"currentStrength"] doubleValue] : 1.0;
    self.decayRate = [dict[@"decayRate"] doubleValue];
    self.minimumStrength = dict[@"minimumStrength"] ? [dict[@"minimumStrength"] doubleValue] : 0.1;
    self.strengthHorizon = dict[@"strengthHorizon"];
    self.autoDelete = [dict[@"autoDelete"] boolValue];
    self.lastStrengthUpdate = dict[@"lastStrengthUpdate"] ?: [NSDate date];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"ConnectionModel<%@>: %@ (%@) - %lu symbols, strength: %.1f%%",
            self.connectionID,
            self.title,
            [self typeDisplayString],
            (unsigned long)[self allInvolvedSymbols].count,
            self.currentStrength * 100];
}

@end
