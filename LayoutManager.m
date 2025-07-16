//
//  LayoutManager.m
//  TradingApp
//

#import "LayoutManager.h"

@interface LayoutManager ()
@property (nonatomic, strong) NSTimer *autoSaveTimer;
@property (nonatomic, assign) BOOL autoSaveEnabled;
@property (nonatomic, assign) NSTimeInterval autoSaveInterval;
@end

@implementation LayoutManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoSaveInterval = 300; // 5 minutes default
        [self createLayoutsDirectory];
    }
    return self;
}

- (void)createLayoutsDirectory {
    NSString *layoutsPath = [self layoutsDirectoryPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:layoutsPath]) {
        NSError *error;
        [fileManager createDirectoryAtPath:layoutsPath
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&error];
        if (error) {
            NSLog(@"Error creating layouts directory: %@", error);
        }
    }
}

- (NSString *)layoutsDirectoryPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                         NSUserDomainMask, YES);
    NSString *applicationSupport = paths.firstObject;
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    return [applicationSupport stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@/Layouts", bundleID]];
}

- (NSString *)pathForLayoutName:(NSString *)layoutName {
    return [[self layoutsDirectoryPath]
            stringByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.plist", layoutName]];
}

#pragma mark - Save/Load

- (void)saveLayout:(NSDictionary *)layoutData withName:(NSString *)layoutName {
    if (!layoutData || !layoutName) {
        NSLog(@"ERROR: Cannot save layout - layoutData or layoutName is nil");
        return;
    }
    
    NSLog(@"LayoutManager saving layout '%@'", layoutName);
    
    NSString *path = [self pathForLayoutName:layoutName];
    NSError *error;
    
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:layoutData
                                                               format:NSPropertyListXMLFormat_v1_0
                                                              options:0
                                                                error:&error];
    if (error) {
        NSLog(@"Error serializing layout: %@", error);
        return;
    }
    
    BOOL success = [data writeToFile:path atomically:YES];
    NSLog(@"Saved layout to file: %@ (success: %@)", path, success ? @"YES" : @"NO");
    
    // Also save to user defaults for quick access
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:layoutData forKey:[NSString stringWithFormat:@"Layout_%@", layoutName]];
    [defaults synchronize];
    
    NSLog(@"Saved layout to user defaults");
}

- (NSDictionary *)loadLayoutWithName:(NSString *)layoutName {
    if (!layoutName) return nil;
    
    // Try user defaults first (faster)
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *layoutData = [defaults objectForKey:
                                [NSString stringWithFormat:@"Layout_%@", layoutName]];
    
    if (layoutData) {
        return layoutData;
    }
    
    // Fall back to file
    NSString *path = [self pathForLayoutName:layoutName];
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    if (!data) {
        return nil;
    }
    
    NSError *error;
    layoutData = [NSPropertyListSerialization propertyListWithData:data
                                                           options:NSPropertyListImmutable
                                                            format:nil
                                                             error:&error];
    if (error) {
        NSLog(@"Error loading layout: %@", error);
        return nil;
    }
    
    return layoutData;
}

- (void)deleteLayoutWithName:(NSString *)layoutName {
    if (!layoutName) return;
    
    // Remove from file system
    NSString *path = [self pathForLayoutName:layoutName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    
    [fileManager removeItemAtPath:path error:&error];
    if (error) {
        NSLog(@"Error deleting layout file: %@", error);
    }
    
    // Remove from user defaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:[NSString stringWithFormat:@"Layout_%@", layoutName]];
    [defaults synchronize];
}

#pragma mark - List Layouts

- (NSArray<NSString *> *)availableLayouts {
    NSMutableArray *layouts = [NSMutableArray array];
    
    // Get from file system
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *files = [fileManager contentsOfDirectoryAtPath:[self layoutsDirectoryPath]
                                                       error:&error];
    
    if (!error) {
        for (NSString *file in files) {
            if ([file hasSuffix:@".plist"]) {
                NSString *layoutName = [file stringByDeletingPathExtension];
                [layouts addObject:layoutName];
            }
        }
    }
    
    // Also check user defaults for any not saved to disk
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    
    for (NSString *key in allDefaults.allKeys) {
        if ([key hasPrefix:@"Layout_"]) {
            NSString *layoutName = [key substringFromIndex:7];
            if (![layouts containsObject:layoutName]) {
                [layouts addObject:layoutName];
            }
        }
    }
    
    return [layouts sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

#pragma mark - Import/Export

- (BOOL)exportLayoutWithName:(NSString *)layoutName toPath:(NSString *)path {
    NSDictionary *layoutData = [self loadLayoutWithName:layoutName];
    if (!layoutData) return NO;
    
    NSError *error;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:layoutData
                                                               format:NSPropertyListXMLFormat_v1_0
                                                              options:0
                                                                error:&error];
    if (error) {
        NSLog(@"Error exporting layout: %@", error);
        return NO;
    }
    
    return [data writeToFile:path atomically:YES];
}

- (BOOL)importLayoutFromPath:(NSString *)path withName:(NSString *)layoutName {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return NO;
    
    NSError *error;
    NSDictionary *layoutData = [NSPropertyListSerialization propertyListWithData:data
                                                                        options:NSPropertyListImmutable
                                                                         format:nil
                                                                          error:&error];
    if (error) {
        NSLog(@"Error importing layout: %@", error);
        return NO;
    }
    
    [self saveLayout:layoutData withName:layoutName];
    return YES;
}

#pragma mark - Auto Save

- (void)enableAutoSave:(BOOL)enable {
    self.autoSaveEnabled = enable;
    
    if (enable) {
        [self startAutoSaveTimer];
    } else {
        [self stopAutoSaveTimer];
    }
}

- (void)setAutoSaveInterval:(NSTimeInterval)interval {
    _autoSaveInterval = interval;
    
    if (self.autoSaveEnabled) {
        [self stopAutoSaveTimer];
        [self startAutoSaveTimer];
    }
}

- (void)startAutoSaveTimer {
    self.autoSaveTimer = [NSTimer scheduledTimerWithTimeInterval:self.autoSaveInterval
                                                          target:self
                                                        selector:@selector(performAutoSave:)
                                                        userInfo:nil
                                                         repeats:YES];
}

- (void)stopAutoSaveTimer {
    [self.autoSaveTimer invalidate];
    self.autoSaveTimer = nil;
}

- (void)performAutoSave:(NSTimer *)timer {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"AutoSaveLayout" object:nil];
}

- (void)dealloc {
    [self stopAutoSaveTimer];
}

@end
