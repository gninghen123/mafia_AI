//  Watchlist+Extensions.m
//  mafia_AI
//

#import "Watchlist+Extensions.h"
#import <objc/runtime.h>

static void *IsFavoriteKey = &IsFavoriteKey;

@implementation Watchlist (Extensions)

- (BOOL)isFavorite {
    NSNumber *value = objc_getAssociatedObject(self, IsFavoriteKey);
    return [value boolValue];
}

- (void)setIsFavorite:(BOOL)isFavorite {
    objc_setAssociatedObject(self, IsFavoriteKey, @(isFavorite), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
