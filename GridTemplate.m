//
//  GridTemplate.m
//  TradingApp
//

#import "GridTemplate.h"

// Template type constants
GridTemplateType const GridTemplateTypeListChart = @"ListChart";
GridTemplateType const GridTemplateTypeListDualChart = @"ListDualChart";
GridTemplateType const GridTemplateTypeTripleHorizontal = @"TripleHorizontal";
GridTemplateType const GridTemplateTypeQuad = @"Quad";
GridTemplateType const GridTemplateTypeCustom = @"Custom";

// Position constants
GridPosition const GridPositionLeft = @"Left";
GridPosition const GridPositionRight = @"Right";
GridPosition const GridPositionTop = @"Top";
GridPosition const GridPositionBottom = @"Bottom";
GridPosition const GridPositionTopLeft = @"TopLeft";
GridPosition const GridPositionTopRight = @"TopRight";
GridPosition const GridPositionBottomLeft = @"BottomLeft";
GridPosition const GridPositionBottomRight = @"BottomRight";

@interface GridTemplate ()
@property (nonatomic, strong, readwrite) GridTemplateType templateType;
@property (nonatomic, strong, readwrite) NSString *displayName;
@property (nonatomic, assign, readwrite) NSInteger maxWidgets;
@property (nonatomic, strong, readwrite) NSArray<GridPosition> *availablePositions;
@end

@implementation GridTemplate

+ (instancetype)templateWithType:(GridTemplateType)type {
    GridTemplate *template = [[GridTemplate alloc] init];
    template.templateType = type;
    
    if ([type isEqualToString:GridTemplateTypeListChart]) {
        template.displayName = @"List + Chart";
        template.maxWidgets = 2;
        template.availablePositions = @[GridPositionLeft, GridPositionRight];
        
    } else if ([type isEqualToString:GridTemplateTypeListDualChart]) {
        template.displayName = @"List + Dual Charts";
        template.maxWidgets = 3;
        template.availablePositions = @[GridPositionLeft, GridPositionTopRight, GridPositionBottomRight];
        
    } else if ([type isEqualToString:GridTemplateTypeTripleHorizontal]) {
        template.displayName = @"Triple Horizontal";
        template.maxWidgets = 3;
        template.availablePositions = @[GridPositionLeft, GridPositionRight, GridPositionBottom];
        
    } else if ([type isEqualToString:GridTemplateTypeQuad]) {
        template.displayName = @"2x2 Grid";
        template.maxWidgets = 4;
        template.availablePositions = @[GridPositionTopLeft, GridPositionTopRight,
                                        GridPositionBottomLeft, GridPositionBottomRight];
    } else {
        template.displayName = @"Custom";
        template.maxWidgets = 10;
        template.availablePositions = @[];
    }
    
    return template;
}

+ (NSArray<GridTemplate *> *)allTemplates {
    return @[
        [GridTemplate templateWithType:GridTemplateTypeListChart],
        [GridTemplate templateWithType:GridTemplateTypeListDualChart],
        [GridTemplate templateWithType:GridTemplateTypeTripleHorizontal],
        [GridTemplate templateWithType:GridTemplateTypeQuad]
    ];
}

- (NSSplitView *)createLayoutView {
    if ([self.templateType isEqualToString:GridTemplateTypeListChart]) {
        return [self createListChartLayout];
        
    } else if ([self.templateType isEqualToString:GridTemplateTypeListDualChart]) {
        return [self createListDualChartLayout];
        
    } else if ([self.templateType isEqualToString:GridTemplateTypeTripleHorizontal]) {
        return [self createTripleHorizontalLayout];
        
    } else if ([self.templateType isEqualToString:GridTemplateTypeQuad]) {
        return [self createQuadLayout];
    }
    
    return nil;
}

- (GridPosition)positionForWidgetAtIndex:(NSInteger)index {
    if (index < self.availablePositions.count) {
        return self.availablePositions[index];
    }
    return GridPositionLeft;
}

#pragma mark - Layout Creation Methods

- (NSSplitView *)createListChartLayout {
    // Simple vertical split: 30% left, 70% right
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    return splitView;
}

- (NSSplitView *)createListDualChartLayout {
    // Left (25%) | Right split vertically (75%)
    NSSplitView *mainSplit = [[NSSplitView alloc] init];
    mainSplit.vertical = YES;
    mainSplit.dividerStyle = NSSplitViewDividerStyleThin;
    
    NSSplitView *rightSplit = [[NSSplitView alloc] init];
    rightSplit.vertical = NO;
    rightSplit.dividerStyle = NSSplitViewDividerStyleThin;
    
    return mainSplit; // rightSplit verrà aggiunto come subview
}

- (NSSplitView *)createTripleHorizontalLayout {
    // Three equal horizontal sections
    NSSplitView *splitView = [[NSSplitView alloc] init];
    splitView.vertical = YES;
    splitView.dividerStyle = NSSplitViewDividerStyleThin;
    return splitView;
}

- (NSSplitView *)createQuadLayout {
    // 2x2 grid using nested splits
    NSSplitView *mainSplit = [[NSSplitView alloc] init];
    mainSplit.vertical = NO;
    mainSplit.dividerStyle = NSSplitViewDividerStyleThin;
    
    NSSplitView *topSplit = [[NSSplitView alloc] init];
    topSplit.vertical = YES;
    topSplit.dividerStyle = NSSplitViewDividerStyleThin;
    
    NSSplitView *bottomSplit = [[NSSplitView alloc] init];
    bottomSplit.vertical = YES;
    bottomSplit.dividerStyle = NSSplitViewDividerStyleThin;
    
    return mainSplit;
}

@end
