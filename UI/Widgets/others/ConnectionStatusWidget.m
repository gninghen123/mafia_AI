//
//  ConnectionStatusWidget.m
//  TradingApp
//

#import "ConnectionStatusWidget.h"
#import "DownloadManager.h"

@interface ConnectionStatusWidget ()
@property (nonatomic, strong) NSTextField *statusLabelInternal;
@property (nonatomic, strong) NSTextField *sourceLabelInternal;
@property (nonatomic, strong) NSButton *connectButtonInternal;
@property (nonatomic, strong) NSProgressIndicator *activityIndicatorInternal;
@property (nonatomic, strong) DataManager *dataManager;
@property (nonatomic, strong) NSTimer *statusTimer;
@end

@implementation ConnectionStatusWidget

- (instancetype)initWithType:(NSString *)type {
    self = [super initWithType:type];
    if (self) {
        self.widgetType = @"Connection Status";
        self.dataManager = [DataManager sharedManager];
        [self.dataManager addDelegate:self];
    }
    return self;
}


- (void)setupContentView {
    [super setupContentView];
    
    // Create main stack view
    NSStackView *mainStack = [[NSStackView alloc] init];
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.spacing = 15;
    mainStack.edgeInsets = NSEdgeInsetsMake(15, 20, 15, 20);
    mainStack.distribution = NSStackViewDistributionFillEqually;
    
    // Status section
    NSView *statusSection = [self createStatusSection];
    
    // Source info section
    NSView *sourceSection = [self createSourceSection];
    
    // Connect button
    self.connectButtonInternal = [[NSButton alloc] init];
    self.connectButtonInternal.bezelStyle = NSBezelStyleRounded;
    self.connectButtonInternal.title = @"Connect to Schwab";
    self.connectButtonInternal.target = self;
    self.connectButtonInternal.action = @selector(connectToSchwab:);
    
    // Activity indicator
    self.activityIndicatorInternal = [[NSProgressIndicator alloc] init];
    self.activityIndicatorInternal.style = NSProgressIndicatorStyleSpinning;
    self.activityIndicatorInternal.controlSize = NSControlSizeSmall;
    self.activityIndicatorInternal.hidden = YES;
    
    // Add all to stack
    [mainStack addArrangedSubview:statusSection];
    [mainStack addArrangedSubview:sourceSection];
    [mainStack addArrangedSubview:self.connectButtonInternal];
    [mainStack addArrangedSubview:self.activityIndicatorInternal];
    
    // Add stack to content view
    [self.contentView addSubview:mainStack];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [mainStack.bottomAnchor constraintLessThanOrEqualToAnchor:self.contentView.bottomAnchor]
    ]];
    
    // Start status updates
    [self updateStatus];
    self.statusTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                        target:self
                                                      selector:@selector(updateStatus)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (NSView *)createStatusSection {
    NSView *container = [[NSView alloc] init];
    
    NSTextField *titleLabel = [self createLabel:@"Connection Status:" fontSize:12 weight:NSFontWeightMedium];
    titleLabel.textColor = [NSColor secondaryLabelColor];
    
    self.statusLabelInternal = [self createLabel:@"Checking..." fontSize:16 weight:NSFontWeightSemibold];
    
    [container addSubview:titleLabel];
    [container addSubview:self.statusLabelInternal];
    
    // Layout
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabelInternal.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        
        [self.statusLabelInternal.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5],
        [self.statusLabelInternal.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.statusLabelInternal.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    
    return container;
}

- (NSView *)createSourceSection {
    NSView *container = [[NSView alloc] init];
    
    NSTextField *titleLabel = [self createLabel:@"Active Data Source:" fontSize:12 weight:NSFontWeightMedium];
    titleLabel.textColor = [NSColor secondaryLabelColor];
    
    self.sourceLabelInternal = [self createLabel:@"None" fontSize:16 weight:NSFontWeightSemibold];
    
    [container addSubview:titleLabel];
    [container addSubview:self.sourceLabelInternal];
    
    // Layout
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.sourceLabelInternal.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
        [titleLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        
        [self.sourceLabelInternal.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:5],
        [self.sourceLabelInternal.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [self.sourceLabelInternal.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];
    
    return container;
}

- (NSTextField *)createLabel:(NSString *)text fontSize:(CGFloat)fontSize weight:(NSFontWeight)weight {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.editable = NO;
    label.bordered = NO;
    label.backgroundColor = [NSColor clearColor];
    label.font = [NSFont systemFontOfSize:fontSize weight:weight];
    label.alignment = NSTextAlignmentLeft;
    return label;
}

#pragma mark - Status Updates

- (void)updateStatus {
    BOOL isConnected = self.dataManager.isConnected;
    NSString *activeSource = self.dataManager.activeDataSource;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isConnected) {
            self.statusLabelInternal.stringValue = @"Connected";
            self.statusLabelInternal.textColor = [NSColor systemGreenColor];
            
            self.sourceLabelInternal.stringValue = activeSource;
            
            if ([activeSource isEqualToString:@"Charles Schwab"]) {
                self.connectButtonInternal.title = @"Schwab Connected";
                self.connectButtonInternal.enabled = NO;
            } else {
                self.connectButtonInternal.title = @"Connect to Schwab";
                self.connectButtonInternal.enabled = YES;
            }
        } else {
            self.statusLabelInternal.stringValue = @"Disconnected";
            self.statusLabelInternal.textColor = [NSColor systemRedColor];
            
            self.sourceLabelInternal.stringValue = @"None";
            
            self.connectButtonInternal.title = @"Connect to Schwab";
            self.connectButtonInternal.enabled = YES;
        }
        
        // Check specific data sources
        [self updateDataSourceStatus];
    });
}

- (void)updateDataSourceStatus {
    DownloadManager *downloadManager = [DownloadManager sharedManager];
    
    NSMutableArray *connectedSources = [NSMutableArray array];
    
    if ([downloadManager isDataSourceConnected:DataSourceTypeSchwab]) {
        [connectedSources addObject:@"Schwab"];
    }
    if ([downloadManager isDataSourceConnected:DataSourceTypeYahoo]) {
        [connectedSources addObject:@"Yahoo"];
    }
    
    if (connectedSources.count > 0) {
        NSString *sourcesText = [connectedSources componentsJoinedByString:@", "];
        self.sourceLabelInternal.stringValue = sourcesText;
    }
}

#pragma mark - Actions

- (void)connectToSchwab:(id)sender {
    self.connectButtonInternal.enabled = NO;
    self.activityIndicatorInternal.hidden = NO;
    [self.activityIndicatorInternal startAnimation:nil];
    
    [[DownloadManager sharedManager] connectDataSource:DataSourceTypeSchwab
                                             completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.activityIndicatorInternal.hidden = YES;
            [self.activityIndicatorInternal stopAnimation:nil];
            self.connectButtonInternal.enabled = YES;
            
            if (success) {
                [self updateStatus];
            } else {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = @"Connection Failed";
                alert.informativeText = error.localizedDescription ?: @"Unable to connect to Schwab";
                [alert addButtonWithTitle:@"OK"];
                [alert runModal];
            }
        });
    }];
}

#pragma mark - Properties

- (NSTextField *)statusLabel { return self.statusLabelInternal; }
- (NSTextField *)sourceLabel { return self.sourceLabelInternal; }
- (NSButton *)connectButton { return self.connectButtonInternal; }
- (NSProgressIndicator *)activityIndicator { return self.activityIndicatorInternal; }

#pragma mark - Cleanup

- (void)dealloc {
    [self.statusTimer invalidate];
    [[DataManager sharedManager] removeDelegate:self];
}

@end
