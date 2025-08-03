//
//  DataHub+TickDataProperties.m
//  mafia_AI
//
//  Dynamic properties implementation using associated objects
//

#import "DataHub+TickDataProperties.h"
#import <objc/runtime.h>

@implementation DataHub (TickDataProperties)

#pragma mark - Associated Objects for Tick Data

- (NSMutableDictionary *)tickDataCache {
    NSMutableDictionary *cache = objc_getAssociatedObject(self, @selector(tickDataCache));
    if (!cache) {
        cache = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(tickDataCache), cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

- (void)setTickDataCache:(NSMutableDictionary *)tickDataCache {
    objc_setAssociatedObject(self, @selector(tickDataCache), tickDataCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)tickCacheTimestamps {
    NSMutableDictionary *timestamps = objc_getAssociatedObject(self, @selector(tickCacheTimestamps));
    if (!timestamps) {
        timestamps = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, @selector(tickCacheTimestamps), timestamps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return timestamps;
}

- (void)setTickCacheTimestamps:(NSMutableDictionary *)tickCacheTimestamps {
    objc_setAssociatedObject(self, @selector(tickCacheTimestamps), tickCacheTimestamps, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableSet *)activeTickStreams {
    NSMutableSet *streams = objc_getAssociatedObject(self, @selector(activeTickStreams));
    if (!streams) {
        streams = [NSMutableSet set];
        objc_setAssociatedObject(self, @selector(activeTickStreams), streams, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return streams;
}

- (void)setActiveTickStreams:(NSMutableSet *)activeTickStreams {
    objc_setAssociatedObject(self, @selector(activeTickStreams), activeTickStreams, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSTimer *)tickStreamTimer {
    return objc_getAssociatedObject(self, @selector(tickStreamTimer));
}

- (void)setTickStreamTimer:(NSTimer *)tickStreamTimer {
    objc_setAssociatedObject(self, @selector(tickStreamTimer), tickStreamTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
