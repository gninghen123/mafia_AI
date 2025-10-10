//
//  GridTemplate.m
//  TradingApp
//
//  Simplified grid template implementation
//

#import "GridTemplate.h"

@implementation GridTemplate

#pragma mark - Initialization

+ (instancetype)templateWithRows:(NSInteger)rows
                            cols:(NSInteger)cols
                     displayName:(NSString *)name {
    return [self templateWithRows:rows
                             cols:cols
                      displayName:name
                       rowHeights:nil
                     columnWidths:nil];
}

+ (instancetype)templateWithRows:(NSInteger)rows
                            cols:(NSInteger)cols
                     displayName:(NSString *)name
                      rowHeights:(NSArray<NSNumber *> *)rowHeights
                    columnWidths:(NSArray<NSNumber *> *)columnWidths {
    GridTemplate *template = [[GridTemplate alloc] init];
    template.rows = rows;
    template.cols = cols;
    template.displayName = name;
    template.rowHeights = rowHeights;
    template.columnWidths = columnWidths;
    
    // If no proportions provided, create uniform distribution
    if (!rowHeights || !columnWidths) {
        [template resetToUniformProportions];
    }
    
    return template;
}

#pragma mark - Proportions Management

- (void)resetToUniformProportions {
    // Create uniform distribution for rows
    NSMutableArray<NSNumber *> *uniformRows = [NSMutableArray arrayWithCapacity:self.rows];
    CGFloat baseRowHeight = 1.0 / self.rows;
    for (NSInteger i = 0; i < self.rows; i++) {
        [uniformRows addObject:@(baseRowHeight)];
    }
    
    // Adjust last element to ensure sum = 1.0 (avoid floating point errors)
    if (self.rows > 0) {
        CGFloat sum = 0.0;
        for (NSInteger i = 0; i < self.rows - 1; i++) {
            sum += [uniformRows[i] doubleValue];
        }
        uniformRows[self.rows - 1] = @(1.0 - sum);
    }
    
    // Create uniform distribution for columns
    NSMutableArray<NSNumber *> *uniformCols = [NSMutableArray arrayWithCapacity:self.cols];
    CGFloat baseColWidth = 1.0 / self.cols;
    for (NSInteger i = 0; i < self.cols; i++) {
        [uniformCols addObject:@(baseColWidth)];
    }
    
    // Adjust last element
    if (self.cols > 0) {
        CGFloat sum = 0.0;
        for (NSInteger i = 0; i < self.cols - 1; i++) {
            sum += [uniformCols[i] doubleValue];
        }
        uniformCols[self.cols - 1] = @(1.0 - sum);
    }
    
    self.rowHeights = uniformRows;
    self.columnWidths = uniformCols;
    
    NSLog(@"📏 GridTemplate: Reset to uniform proportions - Rows: %@, Cols: %@",
          self.rowHeights, self.columnWidths);
}

- (BOOL)validateProportions {
    // Check arrays exist
    if (!self.rowHeights || !self.columnWidths) {
        return NO;
    }
    
    // Check correct count
    if (self.rowHeights.count != self.rows || self.columnWidths.count != self.cols) {
        NSLog(@"⚠️ GridTemplate: Invalid proportions count - Expected rows:%ld cols:%ld, got rows:%ld cols:%ld",
              (long)self.rows, (long)self.cols,
              (long)self.rowHeights.count, (long)self.columnWidths.count);
        return NO;
    }
    
    // Check sum to ~1.0 (allow small floating point error)
    CGFloat rowSum = 0.0;
    for (NSNumber *height in self.rowHeights) {
        rowSum += [height doubleValue];
    }
    
    CGFloat colSum = 0.0;
    for (NSNumber *width in self.columnWidths) {
        colSum += [width doubleValue];
    }
    
    const CGFloat epsilon = 0.001; // Tolerance for floating point comparison
    BOOL rowSumValid = fabs(rowSum - 1.0) < epsilon;
    BOOL colSumValid = fabs(colSum - 1.0) < epsilon;
    
    if (!rowSumValid || !colSumValid) {
        NSLog(@"⚠️ GridTemplate: Invalid proportions sum - Row sum:%.4f, Col sum:%.4f",
              rowSum, colSum);
        return NO;
    }
    
    return YES;
}

- (NSInteger)totalCells {
    return self.rows * self.cols;
}

#pragma mark - Serialization

- (NSDictionary *)serialize {
    return @{
        @"rows": @(self.rows),
        @"cols": @(self.cols),
        @"displayName": self.displayName ?: @"Custom Grid",
        @"rowHeights": self.rowHeights ?: @[],
        @"columnWidths": self.columnWidths ?: @[]
    };
}

+ (instancetype)deserialize:(NSDictionary *)dict {
    if (!dict || !dict[@"rows"] || !dict[@"cols"]) {
        NSLog(@"⚠️ GridTemplate: Invalid serialization data");
        return nil;
    }
    
    NSInteger rows = [dict[@"rows"] integerValue];
    NSInteger cols = [dict[@"cols"] integerValue];
    NSString *name = dict[@"displayName"] ?: @"Custom Grid";
    NSArray<NSNumber *> *rowHeights = dict[@"rowHeights"];
    NSArray<NSNumber *> *columnWidths = dict[@"columnWidths"];
    
    // Validate dimensions
    if (rows < 1 || rows > 3 || cols < 1 || cols > 3) {
        NSLog(@"⚠️ GridTemplate: Invalid dimensions - rows:%ld cols:%ld", (long)rows, (long)cols);
        return nil;
    }
    
    GridTemplate *template = [self templateWithRows:rows
                                               cols:cols
                                        displayName:name
                                         rowHeights:rowHeights
                                       columnWidths:columnWidths];
    
    // Validate proportions, reset if invalid
    if (![template validateProportions]) {
        NSLog(@"⚠️ GridTemplate: Invalid proportions in serialized data, resetting to uniform");
        [template resetToUniformProportions];
    }
    
    return template;
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<GridTemplate: %@ (%ldx%ld) - %ld cells>",
            self.displayName, (long)self.rows, (long)self.cols, (long)[self totalCells]];
}

@end
