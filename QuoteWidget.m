//
//  QuoteWidget.m
//  TradingApp
//

#import "QuoteWidget.h"
#import "MarketDataModels.h"

@interface QuoteWidget ()
@property (nonatomic, strong) NSTextField *symbolLabelInternal;
@property (nonatomic, strong) NSTextField *priceLabelInternal;
@property (nonatomic, strong) NSTextField *changeLabelInternal;
@property (nonatomic, strong) NSTextField *volumeLabelInternal;
@property (nonatomic, strong) NSTextField *bidAskLabelInternal;
@property (nonatomic, strong) NSTextField *timestampLabel;
@property (nonatomic, strong) NSProgressIndicator *loadingIndicator;
@property (nonatomic, strong) MarketData *currentQuote;
@property (nonatomic, strong) DataManager *dataManager;
@end

@implementation QuoteWidget

- (instancetype)initWithType:(NSString *)type panelType:(PanelType)panelType {
    self = [super initWithType:type panelType:panelType];
    if (self) {
        self.widgetType = @"Quote";
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
    mainStack.spacing = 10;
    mainStack.edgeInsets = NSEdgeInsetsMake(10, 15, 10, 15);
    mainStack.distribution = NSStackViewDistributionFillEqually;
    
    // Symbol and loading indicator
    NSView *symbolContainer = [[NSView alloc] init];
    
    self.symbolLabelInternal = [self createLabel:@"--" fontSize:24 weight:NSFontWeightBold];
    self.symbolLabelInternal.textColor = [NSColor labelColor];
    
    self.loadingIndicator = [[NSProgressIndicator alloc] init];
    self.loadingIndicator.style = NSProgressIndicatorStyleSpinning;
    self.loadingIndicator.controlSize = NSControlSizeSmall;
    self.loadingIndicator.hidden = YES;
    
    [symbolContainer addSubview:self.symbolLabelInternal];
    [symbolContainer addSubview:self.loadingIndicator];
    
    // Layout symbol and loading indicator
    self.symbolLabelInternal.translatesAutoresizingMaskIntoConstraints = NO;
    self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.symbolLabelInternal.leadingAnchor constraintEqualToAnchor:symbolContainer.leadingAnchor],
        [self.symbolLabelInternal.centerYAnchor constraintEqualToAnchor:symbolContainer.centerYAnchor],
        
        [self.loadingIndicator.leadingAnchor constraintEqualToAnchor:self.symbolLabelInternal.trailingAnchor constant:10],
        [self.loadingIndicator.centerYAnchor constraintEqualToAnchor:symbolContainer.centerYAnchor],
        [self.loadingIndicator.widthAnchor constraintEqualToConstant:16],
        [self.loadingIndicator.heightAnchor constraintEqualToConstant:16]
    ]];
    
    // Price
    self.priceLabelInternal = [self createLabel:@"--" fontSize:28 weight:NSFontWeightMedium];
    
    // Change
    self.changeLabelInternal = [self createLabel:@"--" fontSize:16 weight:NSFontWeightRegular];
    
    // Bid/Ask
    self.bidAskLabelInternal = [self createLabel:@"Bid: -- / Ask: --" fontSize:14 weight:NSFontWeightRegular];
    self.bidAskLabelInternal.textColor = [NSColor secondaryLabelColor];
    
    // Volume
    self.volumeLabelInternal = [self createLabel:@"Volume: --" fontSize:14 weight:NSFontWeightRegular];
    self.volumeLabelInternal.textColor = [NSColor secondaryLabelColor];
    
    // Timestamp
    self.timestampLabel = [self createLabel:@"Updated: --" fontSize:12 weight:NSFontWeightRegular];
    self.timestampLabel.textColor = [NSColor tertiaryLabelColor];
    
    // Add all to stack
    [mainStack addArrangedSubview:symbolContainer];
    [mainStack addArrangedSubview:self.priceLabelInternal];
    [mainStack addArrangedSubview:self.changeLabelInternal];
    [mainStack addArrangedSubview:self.bidAskLabelInternal];
    [mainStack addArrangedSubview:self.volumeLabelInternal];
    [mainStack addArrangedSubview:self.timestampLabel];
    
    // Add stack to content view
    [self.contentView addSubview:mainStack];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [mainStack.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [mainStack.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [mainStack.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [mainStack.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];
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

#pragma mark - Symbol Management

- (void)setSymbol:(NSString *)symbol {
    if ([_symbol isEqualToString:symbol]) return;
    
    // Unsubscribe from old symbol
    if (_symbol) {
        [self.dataManager unsubscribeFromQuotes:@[_symbol]];
    }
    
    _symbol = symbol;
    
    if (symbol && symbol.length > 0) {
        self.symbolLabelInternal.stringValue = symbol;
        
        // Show loading
        self.loadingIndicator.hidden = NO;
        [self.loadingIndicator startAnimation:nil];
        
        // Subscribe to new symbol
        [self.dataManager subscribeToQuotes:@[symbol]];
        
        // Request immediate quote
        [self.dataManager requestQuoteForSymbol:symbol completion:^(MarketData *quote, NSError *error) {
            if (!error && quote) {
                [self updateWithQuote:quote];
            }
            
            self.loadingIndicator.hidden = YES;
            [self.loadingIndicator stopAnimation:nil];
        }];
    } else {
        [self clearDisplay];
    }
    
    // Broadcast symbol change to chained widgets
    if (self.chainedWidgets.count > 0) {
        [self broadcastUpdate:@{@"symbol": symbol ?: @""}];
    }
}

#pragma mark - Display Updates

- (void)updateWithQuote:(MarketData *)quote {
    self.currentQuote = quote;
    
    // Update price
    if (quote.last) {
        self.priceLabelInternal.stringValue = [NSString stringWithFormat:@"$%.2f", quote.last.doubleValue];
    }
    
    // Update change with color
    if (quote.change && quote.changePercent) {
        NSString *changeStr = [NSString stringWithFormat:@"%@%.2f (%.2f%%)",
                               quote.change.doubleValue >= 0 ? @"+" : @"",
                               quote.change.doubleValue,
                               quote.changePercent.doubleValue];
        
        self.changeLabelInternal.stringValue = changeStr;
        
        if (quote.change.doubleValue > 0) {
            self.changeLabelInternal.textColor = [NSColor systemGreenColor];
        } else if (quote.change.doubleValue < 0) {
            self.changeLabelInternal.textColor = [NSColor systemRedColor];
        } else {
            self.changeLabelInternal.textColor = [NSColor labelColor];
        }
    }
    
    // Update bid/ask
    if (quote.bid && quote.ask) {
        self.bidAskLabelInternal.stringValue = [NSString stringWithFormat:@"Bid: $%.2f / Ask: $%.2f",
                                                quote.bid.doubleValue,
                                                quote.ask.doubleValue];
    }
    
    // Update volume
    if (quote.volume > 0) {
        self.volumeLabelInternal.stringValue = [NSString stringWithFormat:@"Volume: %@",
                                               [self formatVolume:quote.volume]];
    }
    
    // Update timestamp
    if (quote.timestamp) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm:ss";
        self.timestampLabel.stringValue = [NSString stringWithFormat:@"Updated: %@",
                                          [formatter stringFromDate:quote.timestamp]];
    }
}

- (void)clearDisplay {
    self.symbolLabelInternal.stringValue = @"--";
    self.priceLabelInternal.stringValue = @"--";
    self.changeLabelInternal.stringValue = @"--";
    self.changeLabelInternal.textColor = [NSColor labelColor];
    self.bidAskLabelInternal.stringValue = @"Bid: -- / Ask: --";
    self.volumeLabelInternal.stringValue = @"Volume: --";
    self.timestampLabel.stringValue = @"Updated: --";
}

- (NSString *)formatVolume:(NSInteger)volume {
    if (volume >= 1000000000) {
        return [NSString stringWithFormat:@"%.1fB", volume / 1000000000.0];
    } else if (volume >= 1000000) {
        return [NSString stringWithFormat:@"%.1fM", volume / 1000000.0];
    } else if (volume >= 1000) {
        return [NSString stringWithFormat:@"%.1fK", volume / 1000.0];
    }
    return [NSString stringWithFormat:@"%ld", (long)volume];
}

#pragma mark - DataManagerDelegate

- (void)dataManager:(id)manager didUpdateQuote:(MarketData *)quote forSymbol:(NSString *)symbol {
    if ([symbol isEqualToString:self.symbol]) {
        [self updateWithQuote:quote];
    }
}

- (void)dataManager:(id)manager didFailWithError:(NSError *)error forRequest:(NSString *)requestID {
    NSLog(@"Quote widget error: %@", error.localizedDescription);
    
    // Show error in UI
    self.priceLabelInternal.stringValue = @"Error";
    self.priceLabelInternal.textColor = [NSColor systemRedColor];
}

#pragma mark - Widget Chain

- (void)receiveUpdate:(NSDictionary *)update fromWidget:(BaseWidget *)sender {
    if (update[@"symbol"]) {
        [self setSymbol:update[@"symbol"]];
    }
}

#pragma mark - State Management

- (NSDictionary *)serializeState {
    NSMutableDictionary *state = [[super serializeState] mutableCopy];
    if (self.symbol) {
        state[@"symbol"] = self.symbol;
    }
    return state;
}

- (void)restoreState:(NSDictionary *)state {
    [super restoreState:state];
    if (state[@"symbol"]) {
        [self setSymbol:state[@"symbol"]];
    }
}

#pragma mark - Properties

- (NSTextField *)symbolLabel { return self.symbolLabelInternal; }
- (NSTextField *)priceLabel { return self.priceLabelInternal; }
- (NSTextField *)changeLabel { return self.changeLabelInternal; }
- (NSTextField *)volumeLabel { return self.volumeLabelInternal; }
- (NSTextField *)bidAskLabel { return self.bidAskLabelInternal; }

#pragma mark - Cleanup

- (void)dealloc {
    [[DataManager sharedManager] removeDelegate:self];
    if (self.symbol) {
        [[DataManager sharedManager] unsubscribeFromQuotes:@[self.symbol]];
    }
}

@end
