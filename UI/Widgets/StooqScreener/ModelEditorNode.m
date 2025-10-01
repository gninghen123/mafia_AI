//
//  ModelEditorNode.m
//  TradingApp
//

#import "ModelEditorNode.h"

@implementation ModelEditorNode

- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
        _isEditable = NO;
    }
    return self;
}

+ (instancetype)modelNodeWithTitle:(NSString *)title {
    ModelEditorNode *node = [[ModelEditorNode alloc] init];
    node.nodeType = ModelEditorNodeTypeModel;
    node.title = title;
    node.isEditable = YES;
    return node;
}

+ (instancetype)stepNodeWithTitle:(NSString *)title step:(id)step {
    ModelEditorNode *node = [[ModelEditorNode alloc] init];
    node.nodeType = ModelEditorNodeTypeStep;
    node.title = title;
    node.representedObject = step;
    node.isEditable = NO;
    return node;
}

+ (instancetype)parameterNodeWithTitle:(NSString *)title
                                 value:(NSString *)value
                                   key:(NSString *)key {
    ModelEditorNode *node = [[ModelEditorNode alloc] init];
    node.nodeType = ModelEditorNodeTypeParameter;
    node.title = title;
    node.value = value;
    node.representedObject = key;  // Store parameter key
    node.isEditable = YES;
    return node;
}

- (void)addChild:(ModelEditorNode *)child {
    child.parent = self;
    [self.children addObject:child];
}

- (void)removeChild:(ModelEditorNode *)child {
    child.parent = nil;
    [self.children removeObject:child];
}

- (NSInteger)indexInParent {
    if (!self.parent) return -1;
    return [self.parent.children indexOfObject:self];
}

@end
