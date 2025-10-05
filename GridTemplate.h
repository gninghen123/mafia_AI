//
//  GridTemplate.h
//  TradingApp
//
//  Template definitions for grid layouts
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// Template identifiers
typedef NSString * GridTemplateType NS_TYPED_ENUM;

extern GridTemplateType const GridTemplateTypeListChart;      // 30% list + 70% chart
extern GridTemplateType const GridTemplateTypeListDualChart;  // 25% list + 75% split(chart+chart)
extern GridTemplateType const GridTemplateTypeTripleHorizontal; // 3 charts horizontal
extern GridTemplateType const GridTemplateTypeQuad;           // 2x2 grid
extern GridTemplateType const GridTemplateTypeCustom;         // User-defined

// Widget position identifiers
typedef NSString * GridPosition NS_TYPED_ENUM;

extern GridPosition const GridPositionLeft;
extern GridPosition const GridPositionRight;
extern GridPosition const GridPositionTop;
extern GridPosition const GridPositionBottom;
extern GridPosition const GridPositionTopLeft;
extern GridPosition const GridPositionTopRight;
extern GridPosition const GridPositionBottomLeft;
extern GridPosition const GridPositionBottomRight;

@interface GridTemplate : NSObject

@property (nonatomic, strong, readonly) GridTemplateType templateType;
@property (nonatomic, strong, readonly) NSString *displayName;
@property (nonatomic, assign, readonly) NSInteger maxWidgets;
@property (nonatomic, strong, readonly) NSArray<GridPosition> *availablePositions;

+ (instancetype)templateWithType:(GridTemplateType)type;
+ (NSArray<GridTemplate *> *)allTemplates;

// Layout configuration
- (NSSplitView *)createLayoutView;
- (GridPosition)positionForWidgetAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
