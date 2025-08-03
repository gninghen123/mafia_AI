
//
//  ChartPanelView.m
//  TradingApp
//

#import "ChartPanelView.h"
#import "ChartWidget.h"

@interface ChartPanelView ()
@property (nonatomic, strong) NSTrackingArea *trackingArea;
@end

@implementation ChartPanelView

- (instancetype)initWithPanelModel:(ChartPanelModel *)panelModel
                        coordinator:(ChartCoordinator *)coordinator
                        chartWidget:(ChartWidget *)chartWidget {
    self = [super init];
    if (self) {
        _panelModel = panelModel;
        _coordinator = coordinator;
        _chartWidget = chartWidget;
        _showYAxis = YES;
        _showTitle = YES;
        
        [self setupView];
        [self setupUI];
    }
    return self;
}

- (void)setupView {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.wantsLayer = YES;
    
    // Set background color based on panel type
    if (self.panelModel.panelType == ChartPanelTypeMain) {
        self.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    } else {
        self.layer.backgroundColor = [[NSColor controlBackgroundColor]
            blendedColorWithFraction:0.05 ofColor:[NSColor systemBlueColor]].CGColor;
    }
    
    self.layer.borderColor = [NSColor separatorColor].CGColor;
    self.layer.borderWidth = 1.0;
}

- (void)setupUI {
    [self setupTitleLabel];
    [self setupDeleteButton];
    [self setupYAxis];
    [self setupConstraints];
    [self updateTrackingAreas];
}

- (void)setupTitleLabel {
    self.titleLabel = [[NSTextField alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.stringValue = self.panelModel.title;
    self.titleLabel.font = [NSFont boldSystemFontOfSize:12];
    self.titleLabel.textColor = [NSColor labelColor];
    self.titleLabel.backgroundColor = [NSColor clearColor];
    self.titleLabel.bordered = NO;
    self.titleLabel.editable = NO;
    self.titleLabel.selectable = NO;
    [self addSubview:self.titleLabel];
}

- (void)setupDeleteButton {
    if (self.panelModel.canBeDeleted) {
        self.deleteButton = [[NSButton alloc] init];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        self.deleteButton.title = @"❌";
        self.deleteButton.font = [NSFont systemFontOfSize:14];
        self.deleteButton.bordered = NO;
        self.deleteButton.target = self;
        self.deleteButton.action = @selector(deleteButtonClicked:);
        self.deleteButton.toolTip = @"Remove this panel";
        [self addSubview:self.deleteButton];
    }
}

- (void)setupYAxis {
    self.yAxisLabel = [[NSTextField alloc] init];
    self.yAxisLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.yAxisLabel.stringValue = @""; // Will be updated during drawing
    self.yAxisLabel.font = [NSFont systemFontOfSize:10];
    self.yAxisLabel.textColor = [NSColor secondaryLabelColor];
    self.yAxisLabel.backgroundColor = [NSColor clearColor];
    self.yAxisLabel.bordered = NO;
    self.yAxisLabel.editable = NO;
    self.yAxisLabel.selectable = NO;
    self.yAxisLabel.alignment = NSTextAlignmentRight;
    [self addSubview:self.yAxisLabel];
}

- (void)setupConstraints {
    NSMutableArray *constraints = [NSMutableArray array];
    
    // Title label constraints
    [constraints addObjectsFromArray:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
    ]];
    
    // Delete button constraints (if exists)
    if (self.deleteButton) {
        [constraints addObjectsFromArray:@[
            [self.deleteButton.topAnchor constraintEqualToAnchor:self.topAnchor constant:4],
            [self.deleteButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.deleteButton.widthAnchor constraintEqualToConstant:20],
            [self.deleteButton.heightAnchor constraintEqualToConstant:20],
        ]];
        
        // Title should not overlap with delete button
        [constraints addObject:
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.deleteButton.leadingAnchor constant:-8]
        ];
    } else {
        // No delete button, title can go to edge
        [constraints addObject:
            [self.titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.trailingAnchor constant:-8]
        ];
    }
    
    // Y-axis label constraints
    [constraints addObjectsFromArray:@[
        [self.yAxisLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.yAxisLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-4],
        [self.yAxisLabel.widthAnchor constraintEqualToConstant:60],
    ]];
    
    [NSLayoutConstraint activateConstraints:constraints];
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    if (!self.historicalData || self.historicalData.count == 0 || !self.panelModel) {
        [self drawPlaceholder:dirtyRect];
        return;
    }
    
    // Draw background
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(dirtyRect);
    
    // Calculate drawing area (exclude title and button areas)
    NSRect drawingRect = [self chartDrawingRect];
    
    // Draw all indicators in this panel
    for (id<IndicatorRenderer> indicator in self.panelModel.indicators) {
        [indicator drawInRect:drawingRect
                     withData:self.historicalData
                  coordinator:self.coordinator];
    }
    
    // Draw crosshair if visible
    if (self.coordinator.crosshairVisible) {
        [self drawCrosshairInRect:drawingRect];
    }
    
    // Update Y-axis labels
    [self updateYAxisLabels:drawingRect];
}

- (void)drawPlaceholder:(NSRect)rect {
    [[NSColor controlBackgroundColor] setFill];
    NSRectFill(rect);
    
    NSString *placeholder = [NSString stringWithFormat:@"%@ - No Data", self.panelModel.title];
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor secondaryLabelColor]
    };
    
    NSSize textSize = [placeholder sizeWithAttributes:attrs];
    NSPoint textPoint = NSMakePoint((rect.size.width - textSize.width) / 2,
                                   (rect.size.height - textSize.height) / 2);
    [placeholder drawAtPoint:textPoint withAttributes:attrs];
}

- (NSRect)chartDrawingRect {
    NSRect bounds = self.bounds;
    
    // Reserve space for title at top
    CGFloat topMargin = 24;
    // Reserve space for Y-axis labels on right
    CGFloat rightMargin = 70;
    // Small margins for left and bottom
    CGFloat leftMargin = 4;
    CGFloat bottomMargin = 4;
    
    return NSMakeRect(leftMargin,
                     bottomMargin,
                     bounds.size.width - leftMargin - rightMargin,
                     bounds.size.height - topMargin - bottomMargin);
}

- (void)drawCrosshairInRect:(NSRect)rect {
    NSPoint crosshairPos = self.coordinator.crosshairPosition;
    
    // Only draw crosshair if it's within this panel's drawing area
    if (!NSPointInRect(crosshairPos, rect)) return;
    
    [[NSColor labelColor] colorWithAlphaComponent:0.7].setStroke;
    
    NSBezierPath *crosshair = [NSBezierPath bezierPath];
    crosshair.lineWidth = 1.0;
    
    // Dashed line pattern
    CGFloat dashPattern[] = {4.0, 2.0};
    [crosshair setLineDash:dashPattern count:2 phase:0.0];
    
    // Vertical line
    [crosshair moveToPoint:NSMakePoint(crosshairPos.x, rect.origin.y)];
    [crosshair lineToPoint:NSMakePoint(crosshairPos.x, rect.origin.y + rect.size.height)];
    
    // Horizontal line
    [crosshair moveToPoint:NSMakePoint(rect.origin.x, crosshairPos.y)];
    [crosshair lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, crosshairPos.y)];
    
    [crosshair stroke];
}

- (void)updateYAxisLabels:(NSRect)drawingRect {
    if (!self.showYAxis || self.panelModel.indicators.count == 0) {
        self.yAxisLabel.stringValue = @"";
        return;
    }
    
    // Get the primary indicator's value range
    id<IndicatorRenderer> primaryIndicator = self.panelModel.indicators.firstObject;
    NSRange valueRange = [self.coordinator calculateValueRangeForData:self.historicalData
                                                                 type:[primaryIndicator indicatorType]];
    
    // Show current crosshair value if visible
    if (self.coordinator.crosshairVisible) {
        double currentValue = [self.coordinator valueForYPosition:self.coordinator.crosshairPosition.y
                                                          inRange:valueRange
                                                             rect:drawingRect];
        
        // Format value based on indicator type
        NSString *formattedValue = [self formatValue:currentValue forIndicatorType:[primaryIndicator indicatorType]];
        self.yAxisLabel.stringValue = formattedValue;
    } else {
        self.yAxisLabel.stringValue = @"";
    }
}

- (NSString *)formatValue:(double)value forIndicatorType:(NSString *)indicatorType {
    if ([indicatorType isEqualToString:@"Security"]) {
        return [NSString stringWithFormat:@"$%.2f", value];
    } else if ([indicatorType isEqualToString:@"Volume"]) {
        if (value >= 1000000) {
            return [NSString stringWithFormat:@"%.1fM", value / 1000000.0];
        } else if (value >= 1000) {
            return [NSString stringWithFormat:@"%.1fK", value / 1000.0];
        } else {
            return [NSString stringWithFormat:@"%.0f", value];
        }
    } else if ([indicatorType isEqualToString:@"RSI"]) {
        return [NSString stringWithFormat:@"%.1f", value];
    } else {
        return [NSString stringWithFormat:@"%.2f", value];
    }
}

#pragma mark - Mouse Tracking

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    
    if (self.trackingArea) {
        [self removeTrackingArea:self.trackingArea];
    }
    
    self.trackingArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:(NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow)
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseMoved:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    if (NSPointInRect(localPoint, drawingRect)) {
        [self.coordinator handleMouseMove:localPoint inRect:drawingRect];
        [self setNeedsDisplay:YES];
        
        // Notify chart widget to update other panels
        [self.chartWidget refreshAllPanels];
    }
}

- (void)mouseEntered:(NSEvent *)event {
    self.coordinator.crosshairVisible = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
    self.coordinator.crosshairVisible = NO;
    [self setNeedsDisplay:YES];
    [self.chartWidget refreshAllPanels];
}

- (void)scrollWheel:(NSEvent *)event {
    NSPoint localPoint = [self convertPoint:event.locationInWindow fromView:nil];
    NSRect drawingRect = [self chartDrawingRect];
    
    if (event.modifierFlags & NSEventModifierFlagCommand) {
        // Zoom with Command key
        CGFloat zoomFactor = 1.0 + (event.deltaY * 0.01);
        [self.coordinator handleZoom:zoomFactor atPoint:localPoint inRect:drawingRect];
    } else {
        // Pan
        [self.coordinator handleScroll:event.deltaX deltaY:event.deltaY inRect:drawingRect];
    }
    
    [self.chartWidget refreshAllPanels];
}

#pragma mark - Data Updates

- (void)updateWithHistoricalData:(NSArray<HistoricalBarModel *> *)data {
    self.historicalData = data;
    [self setNeedsDisplay:YES];
}

- (void)refreshDisplay {
    [self setNeedsDisplay:YES];
}

- (void)updateUI {
    self.titleLabel.stringValue = self.panelModel.title;
    
    if (self.panelModel.canBeDeleted && !self.deleteButton) {
        [self setupDeleteButton];
        [self setupConstraints];
    } else if (!self.panelModel.canBeDeleted && self.deleteButton) {
        [self.deleteButton removeFromSuperview];
        self.deleteButton = nil;
        [self setupConstraints];
    }
}

#pragma mark - Actions

- (IBAction)deleteButtonClicked:(id)sender {
    NSLog(@"🗑️ Delete panel requested: %@", self.panelModel.title);
    [self.chartWidget requestDeletePanel:self.panelModel];
}

#pragma mark - View Lifecycle

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self updateTrackingAreas];
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

@end
