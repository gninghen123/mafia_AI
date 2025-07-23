//
//  WatchlistCellViews.m
//  mafia_AI
//
//  Custom cell view implementations for WatchlistWidget
//

#import "WatchlistWidget.h"

#pragma mark - Symbol Cell View

@implementation WatchlistSymbolCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.symbolField = [[NSTextField alloc] init];
        self.symbolField.bordered = NO;
        self.symbolField.backgroundColor = [NSColor clearColor];
        self.symbolField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        self.symbolField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.symbolField];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.symbolField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.symbolField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.symbolField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

- (void)setIsEditable:(BOOL)isEditable {
    _isEditable = isEditable;
    self.symbolField.editable = isEditable;
    if (isEditable) {
        self.symbolField.bezeled = YES;
        self.symbolField.bezelStyle = NSTextFieldRoundedBezel;
    } else {
        self.symbolField.bezeled = NO;
    }
}

@end

#pragma mark - Price Cell View

@implementation WatchlistPriceCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.priceField = [[NSTextField alloc] init];
        self.priceField.bordered = NO;
        self.priceField.editable = NO;
        self.priceField.backgroundColor = [NSColor clearColor];
        self.priceField.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
        self.priceField.alignment = NSTextAlignmentRight;
        self.priceField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.priceField];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.priceField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.priceField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.priceField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

@end

#pragma mark - Change Cell View

@implementation WatchlistChangeCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        // Container stack view
        NSStackView *stackView = [[NSStackView alloc] init];
        stackView.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        stackView.spacing = 4;
        stackView.alignment = NSLayoutAttributeCenterY;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Trend icon
        self.trendIcon = [[NSImageView alloc] init];
        self.trendIcon.imageScaling = NSImageScaleProportionallyDown;
        [self.trendIcon setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        
        // Change value field
        self.changeField = [[NSTextField alloc] init];
        self.changeField.bordered = NO;
        self.changeField.editable = NO;
        self.changeField.backgroundColor = [NSColor clearColor];
        self.changeField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
        self.changeField.alignment = NSTextAlignmentRight;
        
        // Percentage field
        self.percentField = [[NSTextField alloc] init];
        self.percentField.bordered = NO;
        self.percentField.editable = NO;
        self.percentField.backgroundColor = [NSColor clearColor];
        self.percentField.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
        self.percentField.alignment = NSTextAlignmentRight;
        
        [stackView addArrangedSubview:self.trendIcon];
        [stackView addArrangedSubview:self.changeField];
        [stackView addArrangedSubview:self.percentField];
        
        [self addSubview:stackView];
        
        [NSLayoutConstraint activateConstraints:@[
            [stackView.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.leadingAnchor constant:8],
            [stackView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [stackView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.trendIcon.widthAnchor constraintEqualToConstant:12],
            [self.trendIcon.heightAnchor constraintEqualToConstant:12]
        ]];
    }
    return self;
}

- (void)setChangeValue:(double)change percentChange:(double)percent {
    BOOL isPositive = change >= 0;
    NSColor *color = isPositive ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    
    // Set icon
    NSString *iconName = isPositive ? @"arrowtriangle.up.fill" : @"arrowtriangle.down.fill";
    self.trendIcon.image = [NSImage imageWithSystemSymbolName:iconName accessibilityDescription:nil];
    self.trendIcon.contentTintColor = color;
    
    // Set text
    self.changeField.stringValue = [NSString stringWithFormat:@"%@%.2f", isPositive ? @"+" : @"", change];
    self.changeField.textColor = color;
    
    self.percentField.stringValue = [NSString stringWithFormat:@"(%@%.2f%%)", isPositive ? @"+" : @"", percent];
    self.percentField.textColor = color;
}

@end

#pragma mark - Volume Cell View

@implementation WatchlistVolumeCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        // Volume text
        self.volumeField = [[NSTextField alloc] init];
        self.volumeField.bordered = NO;
        self.volumeField.editable = NO;
        self.volumeField.backgroundColor = [NSColor clearColor];
        self.volumeField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
        self.volumeField.alignment = NSTextAlignmentRight;
        self.volumeField.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Volume bar (visual indicator)
        self.volumeBar = [[NSProgressIndicator alloc] init];
        self.volumeBar.style = NSProgressIndicatorStyleBar;
        self.volumeBar.indeterminate = NO;
        self.volumeBar.minValue = 0;
        self.volumeBar.maxValue = 100;
        self.volumeBar.controlSize = NSControlSizeSmall;
        self.volumeBar.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.volumeBar];
        [self addSubview:self.volumeField];
        
        [NSLayoutConstraint activateConstraints:@[
            // Volume bar at bottom
            [self.volumeBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.volumeBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.volumeBar.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
            [self.volumeBar.heightAnchor constraintEqualToConstant:4],
            
            // Text above bar
            [self.volumeField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.volumeField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.volumeField.bottomAnchor constraintEqualToAnchor:self.volumeBar.topAnchor constant:-2]
        ]];
    }
    return self;
}

- (void)setVolume:(NSNumber *)volume avgVolume:(NSNumber *)avgVolume {
    if (volume) {
        // Format volume with K, M, B suffixes
        double vol = volume.doubleValue;
        NSString *suffix = @"";
        
        if (vol >= 1e9) {
            vol /= 1e9;
            suffix = @"B";
        } else if (vol >= 1e6) {
            vol /= 1e6;
            suffix = @"M";
        } else if (vol >= 1e3) {
            vol /= 1e3;
            suffix = @"K";
        }
        
        self.volumeField.stringValue = [NSString stringWithFormat:@"%.1f%@", vol, suffix];
        
        // Set progress bar relative to average
        if (avgVolume && avgVolume.doubleValue > 0) {
            double ratio = (volume.doubleValue / avgVolume.doubleValue) * 50; // 50 = midpoint
            self.volumeBar.doubleValue = MIN(100, ratio);
        }
    } else {
        self.volumeField.stringValue = @"--";
        self.volumeBar.doubleValue = 0;
    }
}

@end

#pragma mark - Market Cap Cell View

@implementation WatchlistMarketCapCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.marketCapField = [[NSTextField alloc] init];
        self.marketCapField.bordered = NO;
        self.marketCapField.editable = NO;
        self.marketCapField.backgroundColor = [NSColor clearColor];
        self.marketCapField.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        self.marketCapField.alignment = NSTextAlignmentRight;
        self.marketCapField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.marketCapField];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.marketCapField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.marketCapField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.marketCapField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

- (void)setMarketCap:(NSNumber *)marketCap {
    if (marketCap) {
        double cap = marketCap.doubleValue;
        NSString *suffix = @"";
        
        if (cap >= 1e12) {
            cap /= 1e12;
            suffix = @"T";
        } else if (cap >= 1e9) {
            cap /= 1e9;
            suffix = @"B";
        } else if (cap >= 1e6) {
            cap /= 1e6;
            suffix = @"M";
        }
        
        self.marketCapField.stringValue = [NSString stringWithFormat:@"$%.1f%@", cap, suffix];
    } else {
        self.marketCapField.stringValue = @"--";
    }
}

@end

#pragma mark - Sidebar Cell View

@implementation WatchlistSidebarCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        // Icon
        self.iconView = [[NSImageView alloc] init];
        self.iconView.imageScaling = NSImageScaleProportionallyDown;
        self.iconView.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Name field
        self.nameField = [[NSTextField alloc] init];
        self.nameField.bordered = NO;
        self.nameField.editable = NO;
        self.nameField.backgroundColor = [NSColor clearColor];
        self.nameField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        self.nameField.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Count field
        self.countField = [[NSTextField alloc] init];
        self.countField.bordered = NO;
        self.countField.editable = NO;
        self.countField.backgroundColor = [NSColor clearColor];
        self.countField.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
        self.countField.textColor = [NSColor secondaryLabelColor];
        self.countField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.iconView];
        [self addSubview:self.nameField];
        [self addSubview:self.countField];
        
        [NSLayoutConstraint activateConstraints:@[
            // Icon
            [self.iconView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.iconView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.iconView.widthAnchor constraintEqualToConstant:16],
            [self.iconView.heightAnchor constraintEqualToConstant:16],
            
            // Name
            [self.nameField.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:8],
            [self.nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            
            // Count
            [self.countField.leadingAnchor constraintEqualToAnchor:self.nameField.trailingAnchor constant:8],
            [self.countField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.countField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.countField.widthAnchor constraintEqualToConstant:30]
        ]];
    }
    return self;
}

@end
