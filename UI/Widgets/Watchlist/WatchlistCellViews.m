//
//  WatchlistCellViews.m
//  mafia_AI
//
//  UPDATED: Simplified change cell to show only %change with colors
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
        self.symbolField.backgroundColor = [NSColor controlBackgroundColor];
    } else {
        self.symbolField.bezeled = NO;
        self.symbolField.backgroundColor = [NSColor clearColor];
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

#pragma mark - Change Cell View - SIMPLIFIED TO ONLY %CHANGE

@implementation WatchlistChangeCellView

- (instancetype)init {
    self = [super init];
    if (self) {
        // REMOVED: changeField (dollar change)
        // REMOVED: trendIcon (simplified design)
        
        // Only percent change field
        self.percentField = [[NSTextField alloc] init];
        self.percentField.bordered = NO;
        self.percentField.editable = NO;
        self.percentField.backgroundColor = [NSColor clearColor];
        self.percentField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
        self.percentField.alignment = NSTextAlignmentRight;
        self.percentField.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.percentField];
        
        [NSLayoutConstraint activateConstraints:@[
            [self.percentField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.percentField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.percentField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor]
        ]];
    }
    return self;
}

// UPDATED: Simplified method - only handles percent change
- (void)setChangeValue:(double)change percentChange:(double)percent {
    NSString *sign = percent >= 0 ? @"+" : @"";
    self.percentField.stringValue = [NSString stringWithFormat:@"%@%.2f%%", sign, percent];
    
    // Color coding: Green for positive, Red for negative, Gray for zero
    if (percent > 0) {
        self.percentField.textColor = [NSColor systemGreenColor];
    } else if (percent < 0) {
        self.percentField.textColor = [NSColor systemRedColor];
    } else {
        self.percentField.textColor = [NSColor secondaryLabelColor];
    }
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
        self.volumeField.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
        self.volumeField.alignment = NSTextAlignmentRight;
        self.volumeField.translatesAutoresizingMaskIntoConstraints = NO;
        
        // Volume bar (optional visual indicator)
        self.volumeBar = [[NSProgressIndicator alloc] init];
        self.volumeBar.style = NSProgressIndicatorStyleBar;
        self.volumeBar.indeterminate = NO;
        self.volumeBar.minValue = 0;
        self.volumeBar.maxValue = 100;
        self.volumeBar.doubleValue = 0;
        self.volumeBar.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:self.volumeField];
        [self addSubview:self.volumeBar];
        
        [NSLayoutConstraint activateConstraints:@[
            // Volume field takes most space
            [self.volumeField.topAnchor constraintEqualToAnchor:self.topAnchor constant:2],
            [self.volumeField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.volumeField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.volumeField.bottomAnchor constraintEqualToAnchor:self.volumeBar.topAnchor constant:-2],
            
            // Volume bar at bottom
            [self.volumeBar.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-2],
            [self.volumeBar.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
            [self.volumeBar.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.volumeBar.heightAnchor constraintEqualToConstant:3]
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
        
        // Set progress bar relative to average volume
        if (avgVolume && avgVolume.doubleValue > 0) {
            double ratio = (volume.doubleValue / avgVolume.doubleValue) * 50; // 50 = midpoint
            self.volumeBar.doubleValue = MIN(100, ratio);
            
            // Color the bar based on relative volume
            if (ratio > 75) {
                self.volumeBar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
            } else {
                self.volumeBar.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
            }
        } else {
            self.volumeBar.doubleValue = 25; // Default position
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
    if (marketCap && marketCap.doubleValue > 0) {
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
        } else if (cap >= 1e3) {
            cap /= 1e3;
            suffix = @"K";
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
        self.countField.alignment = NSTextAlignmentRight;
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
            
            // Name field
            [self.nameField.leadingAnchor constraintEqualToAnchor:self.iconView.trailingAnchor constant:8],
            [self.nameField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.nameField.trailingAnchor constraintEqualToAnchor:self.countField.leadingAnchor constant:-8],
            
            // Count field
            [self.countField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
            [self.countField.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [self.countField.widthAnchor constraintEqualToConstant:30]
        ]];
        
        // Set default icon
        self.iconView.image = [NSImage imageNamed:NSImageNameFolder];
    }
    return self;
}

@end
