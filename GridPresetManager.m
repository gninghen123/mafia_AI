//
//  GridPresetManager.m
//  mafia_AI
//
//  Manages custom grid presets (save/load/delete)
//

#import "GridPresetManager.h"
#import "GridTemplate.h"

static NSString * const kCustomPresetsKey = @"CustomGridPresets";

@implementation GridPresetManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static GridPresetManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Private Helpers

- (NSString *)keyForPresetName:(NSString *)name {
    return [NSString stringWithFormat:@"%@_%@", kCustomPresetsKey, name];
}

- (NSMutableDictionary *)loadAllPresetsMetadata {
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kCustomPresetsKey];
    return stored ? [stored mutableCopy] : [NSMutableDictionary dictionary];
}

- (void)saveAllPresetsMetadata:(NSDictionary *)metadata {
    [[NSUserDefaults standardUserDefaults] setObject:metadata forKey:kCustomPresetsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Preset Management

- (BOOL)savePreset:(GridTemplate *)template withName:(NSString *)name {
    if (!template || !name || name.length == 0) {
        NSLog(@"❌ GridPresetManager: Invalid template or name");
        return NO;
    }

    // Serialize template
    NSDictionary *templateData = [template serialize];
    if (!templateData) {
        NSLog(@"❌ GridPresetManager: Failed to serialize template");
        return NO;
    }

    // Save template data
    NSString *key = [self keyForPresetName:name];
    [[NSUserDefaults standardUserDefaults] setObject:templateData forKey:key];

    // Update metadata (list of preset names)
    NSMutableDictionary *metadata = [self loadAllPresetsMetadata];
    metadata[name] = @{
        @"created": [NSDate date],
        @"rows": @(template.rows),
        @"cols": @(template.cols)
    };
    [self saveAllPresetsMetadata:metadata];

    NSLog(@"✅ GridPresetManager: Saved preset '%@' (%ldx%ld)",
          name, (long)template.rows, (long)template.cols);

    return YES;
}

- (BOOL)deletePresetWithName:(NSString *)name {
    if (!name || name.length == 0) {
        return NO;
    }

    // Remove template data
    NSString *key = [self keyForPresetName:name];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];

    // Update metadata
    NSMutableDictionary *metadata = [self loadAllPresetsMetadata];
    [metadata removeObjectForKey:name];
    [self saveAllPresetsMetadata:metadata];

    NSLog(@"🗑️ GridPresetManager: Deleted preset '%@'", name);

    return YES;
}

- (GridTemplate *)loadPresetWithName:(NSString *)name {
    if (!name || name.length == 0) {
        return nil;
    }

    NSString *key = [self keyForPresetName:name];
    NSDictionary *templateData = [[NSUserDefaults standardUserDefaults] dictionaryForKey:key];

    if (!templateData) {
        NSLog(@"❌ GridPresetManager: Preset '%@' not found", name);
        return nil;
    }

    GridTemplate *template = [GridTemplate deserialize:templateData];

    if (template) {
        NSLog(@"✅ GridPresetManager: Loaded preset '%@' (%ldx%ld)",
              name, (long)template.rows, (long)template.cols);
    } else {
        NSLog(@"❌ GridPresetManager: Failed to deserialize preset '%@'", name);
    }

    return template;
}

#pragma mark - Query

- (NSArray<NSString *> *)availablePresetNames {
    NSDictionary *metadata = [self loadAllPresetsMetadata];
    return [metadata.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray<NSDictionary *> *)availablePresets {
    NSArray<NSString *> *names = [self availablePresetNames];
    NSMutableArray *presets = [NSMutableArray arrayWithCapacity:names.count];

    for (NSString *name in names) {
        GridTemplate *template = [self loadPresetWithName:name];
        if (template) {
            [presets addObject:@{
                @"name": name,
                @"template": template
            }];
        }
    }

    return [presets copy];
}

- (BOOL)presetExistsWithName:(NSString *)name {
    if (!name || name.length == 0) {
        return NO;
    }

    NSDictionary *metadata = [self loadAllPresetsMetadata];
    return metadata[name] != nil;
}

@end
