//
//  LayoutManager.h
//  TradingApp
//

#import <Foundation/Foundation.h>

@interface LayoutManager : NSObject

// Save and load layouts
- (void)saveLayout:(NSDictionary *)layoutData withName:(NSString *)layoutName;
- (NSDictionary *)loadLayoutWithName:(NSString *)layoutName;
- (void)deleteLayoutWithName:(NSString *)layoutName;

// List available layouts
- (NSArray<NSString *> *)availableLayouts;

// Import/Export
- (BOOL)exportLayoutWithName:(NSString *)layoutName toPath:(NSString *)path;
- (BOOL)importLayoutFromPath:(NSString *)path withName:(NSString *)layoutName;

// Auto-save
- (void)enableAutoSave:(BOOL)enable;
- (void)setAutoSaveInterval:(NSTimeInterval)interval;

@end
