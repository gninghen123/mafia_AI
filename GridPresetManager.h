//
//  GridPresetManager.h
//  mafia_AI
//
//  Manages custom grid presets (save/load/delete)
//

#import <Foundation/Foundation.h>

@class GridTemplate;

@interface GridPresetManager : NSObject

// Singleton
+ (instancetype)sharedManager;

// Preset Management
- (BOOL)savePreset:(GridTemplate *)template withName:(NSString *)name;
- (BOOL)deletePresetWithName:(NSString *)name;
- (GridTemplate *)loadPresetWithName:(NSString *)name;

// Query
- (NSArray<NSString *> *)availablePresetNames;
- (NSArray<NSDictionary *> *)availablePresets;  // Returns array of @{@"name", @"template"}
- (BOOL)presetExistsWithName:(NSString *)name;

@end
