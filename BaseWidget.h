//
//  BaseWidget.h
//  TradingApp
//

#import <Cocoa/Cocoa.h>
#import "TagManagementWindowController.h"


@interface BaseWidget : NSViewController <TagManagementDelegate>




@property (nonatomic, strong) NSString *widgetType;
@property (nonatomic, strong) NSString *widgetID;
@property (nonatomic, weak, readonly) NSWindow *parentWindow;

// UI Components
@property (nonatomic, strong, readonly) NSView *headerView;
@property (nonatomic, strong, readonly) NSView *contentView;
@property (nonatomic, strong, readonly) NSTextField *titleField;
@property (nonatomic, strong) NSComboBox *titleComboBox;

// Callbacks
@property (nonatomic, copy) void (^onRemoveRequest)(BaseWidget *widget);
@property (nonatomic, copy) void (^onTypeChange)(BaseWidget *widget, NSString *newType);

// Chain system - NEW PROPERTIES
@property (nonatomic, assign) BOOL chainActive;
@property (nonatomic, strong) NSColor *chainColor;  // Colore della chain quando attiva

@property (nonatomic, assign) BOOL isReceivingChainUpdate;





- (instancetype)initWithType:(NSString *)type;  // ✅ SEMPLIFICATO (no panelType)



- (void)showChainFeedback:(NSString *)message;

- (void)sendChainAction:(NSString *)action withData:(id)data;
- (NSMenu *)createChainSubmenuForSymbols:(NSArray<NSString *> *)symbols;


// Widget lifecycle
- (void)setupHeaderView;
- (void)setupContentView;
- (void)updateContentForType:(NSString *)newType;

// State management
- (NSDictionary *)serializeState;
- (void)restoreState:(NSDictionary *)state;

// Chain management - CORE METHODS
- (void)setChainActive:(BOOL)active withColor:(NSColor *)color;
- (void)broadcastUpdate:(NSDictionary *)update;

// ✅ NUOVO: Standard implementation (non override in subclasses)
- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender;
// ✅ NUOVO: Delegation methods (override in subclasses se necessario)
- (void)handleSymbolsFromChain:(NSArray<NSString *> *)symbols fromWidget:(BaseWidget *)sender;
- (void)handleChainAction:(NSString *)action withData:(id)data fromWidget:(BaseWidget *)sender;


- (void)setupStandardContextMenu;

// Chain management - HELPER METHODS (NEW)
- (void)sendSymbolToChain:(NSString *)symbol;
- (void)sendSymbolsToChain:(NSArray<NSString *> *)symbols;
- (NSMenu *)createChainColorSubmenuForSymbols:(NSArray<NSString *> *)symbols;

// Chain context menu actions (NEW)
- (IBAction)contextMenuSendSymbolToChain:(id)sender;
- (IBAction)contextMenuSendSymbolsToChain:(id)sender;
- (IBAction)contextMenuSendToChainColor:(id)sender;


- (void)setupViews;

#pragma mark - Drag & Drop Infrastructure

// Drag & Drop State
@property (nonatomic, assign) BOOL isDragSource;
@property (nonatomic, assign) BOOL isDropTarget;
@property (nonatomic, assign) BOOL isDragging;
@property (nonatomic, assign) BOOL isHovering;

// Drag & Drop Callbacks
@property (nonatomic, copy) void (^onDragBegan)(BaseWidget *widget, id draggedData);
@property (nonatomic, copy) void (^onDragEnded)(BaseWidget *widget, BOOL succeeded);
@property (nonatomic, copy) void (^onDropReceived)(BaseWidget *widget, id droppedData, NSDragOperation operation);

#pragma mark - Drag & Drop Core Methods

// Drag Source Configuration
- (void)enableAsDragSource;
- (void)disableAsDragSource;

// Drop Target Configuration
- (void)enableAsDropTarget;
- (void)disableAsDropTarget;

// Drag Source Protocol (Override in subclasses)
- (NSArray *)draggableData;                     // Data to drag from this widget
- (NSImage *)dragImageForData:(NSArray *)data;  // Custom drag image
- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;

// Drop Target Protocol (Override in subclasses)
- (BOOL)canAcceptDraggedData:(id)data operation:(NSDragOperation)operation;
- (BOOL)handleDroppedData:(id)data operation:(NSDragOperation)operation;
- (NSDragOperation)draggingUpdatedForData:(id)data;

// Visual Feedback Methods
- (void)updateDragVisualFeedback;
- (void)showDropIndicator:(BOOL)show;
- (void)highlightAsDropTarget:(BOOL)highlight;

// Drag Operation Helpers
- (void)startDragWithData:(NSArray *)data fromEvent:(NSEvent *)event;
- (NSString *)pasteboardTypeForDraggedData;

#pragma mark - Default Drag & Drop Behavior

// Generic symbol dragging (works for most widgets)
- (NSArray *)defaultDraggableSymbols;
- (BOOL)defaultHandleDroppedSymbols:(NSArray *)symbols operation:(NSDragOperation)operation;

#pragma mark - Standard Context Menu

// Context menu callbacks - Override in subclasses per personalizzare
@property (nonatomic, copy) void (^onContextMenuWillShow)(BaseWidget *widget, NSMenu *menu);
@property (nonatomic, copy) void (^onSymbolsCopied)(BaseWidget *widget, NSArray<NSString *> *symbols);
@property (nonatomic, copy) void (^onTagsAdded)(BaseWidget *widget, NSArray<NSString *> *symbols, NSArray<NSString *> *tags);

#pragma mark - Context Menu Core Methods

// Menu creation and management
- (NSMenu *)createStandardContextMenu;
- (void)showContextMenuAtPoint:(NSPoint)point;
- (void)appendWidgetSpecificItemsToMenu:(NSMenu *)menu;

// Data source methods - Override in subclasses
- (NSArray<NSString *> *)selectedSymbols;        // Simboli attualmente selezionati
- (NSArray<NSString *> *)contextualSymbols;      // Simboli nel contesto corrente
- (NSString *)contextMenuTitle;                  // Titolo per il menu (es. "Selection" vs "AAPL")

#pragma mark - Standard Context Menu Actions

// Copy operations
- (IBAction)copySelectedSymbols:(id)sender;
- (IBAction)copyAllSymbols:(id)sender;

// Chain operations
- (IBAction)sendToChain:(id)sender;
- (IBAction)sendToChainWithColor:(id)sender;

// Tag operations
- (IBAction)addTagsToSelection:(id)sender;
- (IBAction)showTagManagementPopup:(id)sender;

#pragma mark - Chain Color Management

// Chain color submenu creation
- (NSMenu *)createChainColorSubmenu;
- (NSArray<NSColor *> *)availableChainColors;
- (NSString *)nameForChainColor:(NSColor *)color;

#pragma mark - Default Implementations

// Default behavior that works for most widgets
- (void)copySymbolsToClipboard:(NSArray<NSString *> *)symbols;
- (void)sendSymbolsToChainWithColor:(NSArray<NSString *> *)symbols color:(NSColor *)color;
- (void)addTagsToSymbols:(NSArray<NSString *> *)symbols tags:(NSArray<NSString *> *)tags;
@end
