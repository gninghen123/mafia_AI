//
//  ChartAnnotationsManager.m
//  mafia_AI
//
//  Implementation of ChartAnnotationsManager
//

#import "ChartAnnotationsManager.h"

@interface ChartAnnotationsManager ()

@property (nonatomic, strong, readwrite) NSArray<ChartAnnotation *> *allAnnotations;
@property (nonatomic, strong, readwrite) NSString *currentSymbol;
@property (nonatomic, strong, readwrite) NSDate *startDate;
@property (nonatomic, strong, readwrite) NSDate *endDate;

@end

@implementation ChartAnnotationsManager

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        _providers = @[];
        _allAnnotations = @[];
        _enabledTypes = [NSMutableSet setWithArray:@[
            @(ChartAnnotationTypeNews),
            @(ChartAnnotationTypeNote),
            @(ChartAnnotationTypeAlert)
        ]];
        _minimumRelevanceScore = 50.0;
    }
    return self;
}

- (instancetype)initWithProviders:(NSArray<id<ChartAnnotationProvider>> *)providers {
    self = [self init];
    if (self) {
        _providers = providers ?: @[];
    }
    return self;
}

#pragma mark - Data Loading

- (void)loadAnnotationsForSymbol:(NSString *)symbol
                       startDate:(NSDate *)startDate
                         endDate:(NSDate *)endDate
                      completion:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError * _Nullable error))completion {
    
    if (!symbol || !startDate || !endDate) {
        NSError *error = [NSError errorWithDomain:@"ChartAnnotationsManager"
                                             code:400
                                         userInfo:@{NSLocalizedDescriptionKey: @"Invalid parameters"}];
        if (completion) completion(@[], error);
        return;
    }
    
    self.currentSymbol = symbol;
    self.startDate = startDate;
    self.endDate = endDate;
    
    NSLog(@"📍 ChartAnnotationsManager: Loading annotations for %@ (%@ to %@)",
          symbol, startDate, endDate);
    
    if (self.providers.count == 0) {
        NSLog(@"⚠️ ChartAnnotationsManager: No providers registered");
        self.allAnnotations = @[];
        if (completion) completion(@[], nil);
        return;
    }
    
    // Load from all providers concurrently
    NSMutableArray<ChartAnnotation *> *allLoadedAnnotations = [NSMutableArray array];
    __block NSInteger pendingProviders = self.providers.count;
    __block NSError *firstError = nil;
    
    dispatch_queue_t syncQueue = dispatch_queue_create("com.chartannotations.sync", DISPATCH_QUEUE_SERIAL);
    
    for (id<ChartAnnotationProvider> provider in self.providers) {
        
        [provider getAnnotationsForSymbol:symbol
                                startDate:startDate
                                  endDate:endDate
                               completion:^(NSArray<ChartAnnotation *> *annotations, NSError *error) {
            
            dispatch_async(syncQueue, ^{
                if (annotations) {
                    [allLoadedAnnotations addObjectsFromArray:annotations];
                    NSLog(@"✅ Loaded %lu annotations from %@",
                          (unsigned long)annotations.count,
                          [provider providerName]);
                }
                
                if (error && !firstError) {
                    firstError = error;
                    NSLog(@"❌ Error from %@: %@",
                          [provider providerName],
                          error.localizedDescription);
                }
                
                pendingProviders--;
                
                if (pendingProviders == 0) {
                    // All providers finished
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // Sort by date (newest first)
                        NSArray *sorted = [allLoadedAnnotations sortedArrayUsingComparator:^NSComparisonResult(ChartAnnotation *a, ChartAnnotation *b) {
                            return [b.date compare:a.date];
                        }];
                        
                        self.allAnnotations = sorted;
                        
                        NSLog(@"✅ ChartAnnotationsManager: Loaded %lu total annotations",
                              (unsigned long)sorted.count);
                        
                        if (completion) {
                            completion(sorted, firstError);
                        }
                    });
                }
            });
        }];
    }
}

- (void)reloadAnnotations:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError * _Nullable error))completion {
    if (!self.currentSymbol || !self.startDate || !self.endDate) {
        NSLog(@"⚠️ ChartAnnotationsManager: Cannot reload - no data loaded yet");
        if (completion) completion(@[], nil);
        return;
    }
    
    [self loadAnnotationsForSymbol:self.currentSymbol
                         startDate:self.startDate
                           endDate:self.endDate
                        completion:completion];
}

#pragma mark - Filtering

- (NSArray<ChartAnnotation *> *)filteredAnnotations {
    NSPredicate *filterPredicate = [NSPredicate predicateWithBlock:^BOOL(ChartAnnotation *annotation, NSDictionary *bindings) {
        
        // Check if type is enabled
        if (![self.enabledTypes containsObject:@(annotation.type)]) {
            return NO;
        }
        
        // Check minimum relevance score
        if (annotation.relevanceScore < self.minimumRelevanceScore) {
            return NO;
        }
        
        return YES;
    }];
    
    NSArray *filtered = [self.allAnnotations filteredArrayUsingPredicate:filterPredicate];
    
    NSLog(@"🔍 ChartAnnotationsManager: Filtered %lu/%lu annotations (min score: %.0f)",
          (unsigned long)filtered.count,
          (unsigned long)self.allAnnotations.count,
          self.minimumRelevanceScore);
    
    return filtered;
}

- (void)setAnnotationType:(ChartAnnotationType)type enabled:(BOOL)enabled {
    if (enabled) {
        [self.enabledTypes addObject:@(type)];
    } else {
        [self.enabledTypes removeObject:@(type)];
    }
    
    NSLog(@"📍 ChartAnnotationsManager: Type %ld %@",
          (long)type,
          enabled ? @"enabled" : @"disabled");
}

- (BOOL)isAnnotationTypeEnabled:(ChartAnnotationType)type {
    return [self.enabledTypes containsObject:@(type)];
}

#pragma mark - Query

- (NSArray<ChartAnnotation *> *)annotationsNearDate:(NSDate *)date tolerance:(NSTimeInterval)tolerance {
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(ChartAnnotation *annotation, NSDictionary *bindings) {
        NSTimeInterval diff = fabs([annotation.date timeIntervalSinceDate:date]);
        return diff <= tolerance;
    }];
    
    return [[self filteredAnnotations] filteredArrayUsingPredicate:predicate];
}

- (nullable ChartAnnotation *)annotationWithIdentifier:(NSString *)identifier {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", identifier];
    return [[self.allAnnotations filteredArrayUsingPredicate:predicate] firstObject];
}

#pragma mark - Statistics

- (NSDictionary *)statistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    
    // Total counts
    stats[@"totalAnnotations"] = @(self.allAnnotations.count);
    stats[@"filteredAnnotations"] = @([self filteredAnnotations].count);
    
    // Count by type
    NSMutableDictionary *typeCount = [NSMutableDictionary dictionary];
    for (ChartAnnotation *annotation in self.allAnnotations) {
        NSString *typeKey = [NSString stringWithFormat:@"type_%ld", (long)annotation.type];
        NSInteger count = [typeCount[typeKey] integerValue];
        typeCount[typeKey] = @(count + 1);
    }
    stats[@"countByType"] = typeCount;
    
    // Average score
    if (self.allAnnotations.count > 0) {
        double totalScore = 0;
        for (ChartAnnotation *annotation in self.allAnnotations) {
            totalScore += annotation.relevanceScore;
        }
        stats[@"averageScore"] = @(totalScore / self.allAnnotations.count);
    } else {
        stats[@"averageScore"] = @0;
    }
    
    // Enabled types
    stats[@"enabledTypes"] = [self.enabledTypes allObjects];
    stats[@"minimumScore"] = @(self.minimumRelevanceScore);
    
    return [stats copy];
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<ChartAnnotationsManager: %@ | %lu annotations | %lu providers | score≥%.0f>",
            self.currentSymbol ?: @"(none)",
            (unsigned long)self.allAnnotations.count,
            (unsigned long)self.providers.count,
            self.minimumRelevanceScore];
}

@end
