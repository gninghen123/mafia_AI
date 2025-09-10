//
//  TagManagementWindowController.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>

@class TagManagementWindowController;

@protocol TagManagementDelegate <NSObject>
- (void)tagManagement:(TagManagementWindowController *)controller
       didSelectTags:(NSArray<NSString *> *)tags
          forSymbols:(NSArray<NSString *> *)symbols;
@end

@interface TagManagementWindowController : NSWindowController

@property (nonatomic, weak) id<TagManagementDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<NSString *> *symbols;
@property (nonatomic, strong, readonly) NSArray<NSString *> *selectedTagsArray;

// Factory method
+ (instancetype)windowControllerForSymbols:(NSArray<NSString *> *)symbols;

// Show as modal
- (void)showModalForWindow:(NSWindow *)parentWindow;

@end
