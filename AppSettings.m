//
//  AppSettings.m
//  TradingApp
//

#import "AppSettings.h"

static NSString *const kPriceUpdateIntervalKey = @"PriceUpdateInterval";
static NSString *const kAlertBackupIntervalKey = @"AlertBackupInterval";
static NSString *const kAutosaveLayoutsKey = @"AutosaveLayouts";
static NSString *const kAlertSoundsEnabledKey = @"AlertSoundsEnabled";
static NSString *const kAlertPopupsEnabledKey = @"AlertPopupsEnabled";
static NSString *const kAlertSoundNameKey = @"AlertSoundName";
static NSString *const kYahooEnabledKey = @"YahooEnabled";
static NSString *const kSchwabEnabledKey = @"SchwabEnabled";
static NSString *const kIBKREnabledKey = @"IBKREnabled";
static NSString *const kThemeNameKey = @"ThemeName";
static NSString *const kAccentColorKey = @"AccentColor";

@interface AppSettings ()
@property (nonatomic, strong) NSUserDefaults *userDefaults;
@end

@implementation AppSettings

+ (instancetype)sharedSettings {
    static AppSettings *sharedSettings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSettings = [[self alloc] init];
    });
    return sharedSettings;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
        [self load];
    }
    return self;
}

- (void)load {
    // Load settings with defaults
    self.priceUpdateInterval = [self.userDefaults doubleForKey:kPriceUpdateIntervalKey];
    if (self.priceUpdateInterval == 0) {
        self.priceUpdateInterval = 1.0; // Default 1 second
    }
    
    self.alertBackupInterval = [self.userDefaults doubleForKey:kAlertBackupIntervalKey];
    if (self.alertBackupInterval == 0) {
        self.alertBackupInterval = 5.0; // Default 5 seconds
    }
    
    self.autosaveLayouts = [self.userDefaults boolForKey:kAutosaveLayoutsKey];
    // Default is NO, so no need to check
    
    // Alert Settings
    if ([self.userDefaults objectForKey:kAlertSoundsEnabledKey] == nil) {
        self.alertSoundsEnabled = YES; // Default enabled
    } else {
        self.alertSoundsEnabled = [self.userDefaults boolForKey:kAlertSoundsEnabledKey];
    }
    
    if ([self.userDefaults objectForKey:kAlertPopupsEnabledKey] == nil) {
        self.alertPopupsEnabled = YES; // Default enabled
    } else {
        self.alertPopupsEnabled = [self.userDefaults boolForKey:kAlertPopupsEnabledKey];
    }
    
    self.alertSoundName = [self.userDefaults stringForKey:kAlertSoundNameKey];
    if (!self.alertSoundName) {
        self.alertSoundName = @"Glass"; // Default sound
    }
    
    // Data Source Settings - all enabled by default
    if ([self.userDefaults objectForKey:kYahooEnabledKey] == nil) {
        self.yahooEnabled = YES;
    } else {
        self.yahooEnabled = [self.userDefaults boolForKey:kYahooEnabledKey];
    }
    
    if ([self.userDefaults objectForKey:kSchwabEnabledKey] == nil) {
        self.schwabEnabled = YES;
    } else {
        self.schwabEnabled = [self.userDefaults boolForKey:kSchwabEnabledKey];
    }
    
    if ([self.userDefaults objectForKey:kIBKREnabledKey] == nil) {
        self.ibkrEnabled = YES;
    } else {
        self.ibkrEnabled = [self.userDefaults boolForKey:kIBKREnabledKey];
    }
    
    // Appearance Settings
    self.themeName = [self.userDefaults stringForKey:kThemeNameKey];
    if (!self.themeName) {
        self.themeName = @"System"; // Default theme
    }
    
    NSData *colorData = [self.userDefaults dataForKey:kAccentColorKey];
    if (colorData) {
        self.accentColor = [NSUnarchiver unarchiveObjectWithData:colorData];
    } else {
        self.accentColor = [NSColor systemBlueColor]; // Default color
    }
}

- (void)save {
    // General Settings
    [self.userDefaults setDouble:self.priceUpdateInterval forKey:kPriceUpdateIntervalKey];
    [self.userDefaults setDouble:self.alertBackupInterval forKey:kAlertBackupIntervalKey];
    [self.userDefaults setBool:self.autosaveLayouts forKey:kAutosaveLayoutsKey];
    
    // Alert Settings
    [self.userDefaults setBool:self.alertSoundsEnabled forKey:kAlertSoundsEnabledKey];
    [self.userDefaults setBool:self.alertPopupsEnabled forKey:kAlertPopupsEnabledKey];
    [self.userDefaults setObject:self.alertSoundName forKey:kAlertSoundNameKey];
    
    // Data Source Settings
    [self.userDefaults setBool:self.yahooEnabled forKey:kYahooEnabledKey];
    [self.userDefaults setBool:self.schwabEnabled forKey:kSchwabEnabledKey];
    [self.userDefaults setBool:self.ibkrEnabled forKey:kIBKREnabledKey];
    
    // Appearance Settings
    [self.userDefaults setObject:self.themeName forKey:kThemeNameKey];
    
    NSData *colorData = [NSArchiver archivedDataWithRootObject:self.accentColor];
    [self.userDefaults setObject:colorData forKey:kAccentColorKey];

    [self.userDefaults synchronize];
    
    // Post notification that settings changed
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppSettingsDidChange"
                                                        object:self];
}

- (void)resetToDefaults {
    // Remove all settings to trigger defaults on next load
    NSArray *keys = @[
        kPriceUpdateIntervalKey, kAlertBackupIntervalKey, kAutosaveLayoutsKey,
        kAlertSoundsEnabledKey, kAlertPopupsEnabledKey, kAlertSoundNameKey,
        kYahooEnabledKey, kSchwabEnabledKey, kIBKREnabledKey,
        kThemeNameKey, kAccentColorKey
    ];
    
    for (NSString *key in keys) {
        [self.userDefaults removeObjectForKey:key];
    }
    
    [self.userDefaults synchronize];
    [self load];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AppSettingsDidChange"
                                                        object:self];
}


@end
