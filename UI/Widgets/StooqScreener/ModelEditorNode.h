//
//  ModelEditorNode.h
//  TradingApp
//
//  Node for outline view in model editor
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ModelEditorNodeType) {
    ModelEditorNodeTypeModel,       // Root: model name/description
    ModelEditorNodeTypeStep,        // Screener step
    ModelEditorNodeTypeParameter    // Parameter of a step
};

@interface ModelEditorNode : NSObject

@property (nonatomic, assign) ModelEditorNodeType nodeType;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, nullable) NSString *value;
@property (nonatomic, strong, nullable) id representedObject;  // ScreenerModel, ScreenerStep, or parameter key
@property (nonatomic, strong) NSMutableArray<ModelEditorNode *> *children;
@property (nonatomic, weak, nullable) ModelEditorNode *parent;
@property (nonatomic, assign) BOOL isEditable;

// Factory methods
+ (instancetype)modelNodeWithTitle:(NSString *)title;
+ (instancetype)stepNodeWithTitle:(NSString *)title step:(id)step;
+ (instancetype)parameterNodeWithTitle:(NSString *)title
                                 value:(NSString *)value
                                   key:(NSString *)key;

// Helpers
- (void)addChild:(ModelEditorNode *)child;
- (void)removeChild:(ModelEditorNode *)child;
- (NSInteger)indexInParent;

@end

NS_ASSUME_NONNULL_END
