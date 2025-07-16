//
//  AppSettings.h
//  TradingApp
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface AppSettings : NSObject

+ (instancetype)sharedSettings;

// General Settings
@property (nonatomic, assign) NSTimeInterval priceUpdateInterval;
@property (nonatomic, assign) NSTimeInterval alertBackupInterval;
@property (nonatomic, assign) BOOL autosaveLayouts;

// Alert Settings
@property (nonatomic, assign) BOOL alertSoundsEnabled;
@property (nonatomic, assign) BOOL alertPopupsEnabled;
@property (nonatomic, strong) NSString *alertSoundName;

// Data Source Settings
@property (nonatomic, assign) BOOL yahooEnabled;
@property (nonatomic, assign) BOOL schwabEnabled;
@property (nonatomic, assign) BOOL ibkrEnabled;

// Appearance Settings
@property (nonatomic, strong) NSString *themeName;
@property (nonatomic, strong) NSColor *accentColor;

// Methods
- (void)save;
- (void)load;
- (void)resetToDefaults;

@end
