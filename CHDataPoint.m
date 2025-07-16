//
//  CHDataPoint.m
//  ChartWidget
//
//  Implementation of CHDataPoint
//

#import "CHDataPoint.h"

@implementation CHDataPoint

#pragma mark - Class Methods

+ (instancetype)dataPointWithX:(CGFloat)x y:(CGFloat)y {
    return [[self alloc] initWithX:x y:y];
}

+ (instancetype)dataPointWithX:(CGFloat)x y:(CGFloat)y label:(NSString *)label {
    return [[self alloc] initWithX:x y:y label:label];
}

#pragma mark - Initialization

- (instancetype)init {
    return [self initWithX:0 y:0];
}

- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y {
    return [self initWithX:x y:y label:nil];
}

- (instancetype)initWithX:(CGFloat)x y:(CGFloat)y label:(NSString *)label {
    self = [super init];
    if (self) {
        _x = x;
        _y = y;
        _label = [label copy];
        _seriesIndex = -1;
        _pointIndex = -1;
        _isSelected = NO;
        _isHighlighted = NO;
    }
    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    CHDataPoint *copy = [[CHDataPoint allocWithZone:zone] init];
    if (copy) {
        copy.x = self.x;
        copy.y = self.y;
        copy.seriesIndex = self.seriesIndex;
        copy.pointIndex = self.pointIndex;
        copy.label = [self.label copy];
        copy.tooltip = [self.tooltip copy];
        copy.color = [self.color copy];
        copy.isSelected = self.isSelected;
        copy.isHighlighted = self.isHighlighted;
    }
    return copy;
}

#pragma mark - Utility Methods

- (CGPoint)cgPoint {
    return CGPointMake(self.x, self.y);
}

- (BOOL)isEqualToDataPoint:(CHDataPoint *)dataPoint {
    if (!dataPoint) return NO;
    
    return (self.x == dataPoint.x &&
            self.y == dataPoint.y &&
            self.seriesIndex == dataPoint.seriesIndex &&
            self.pointIndex == dataPoint.pointIndex);
}

#pragma mark - NSObject

- (BOOL)isEqual:(id)object {
    if (self == object) return YES;
    if (![object isKindOfClass:[CHDataPoint class]]) return NO;
    
    return [self isEqualToDataPoint:(CHDataPoint *)object];
}

- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%f,%f,%ld,%ld",
             self.x, self.y, (long)self.seriesIndex, (long)self.pointIndex] hash];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> x:%.2f y:%.2f series:%ld index:%ld%@",
            NSStringFromClass([self class]),
            self,
            self.x,
            self.y,
            (long)self.seriesIndex,
            (long)self.pointIndex,
            self.label ? [NSString stringWithFormat:@" label:'%@'", self.label] : @""];
}

@end
