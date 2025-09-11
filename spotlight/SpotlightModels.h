//
//  SpotlightModels.h
//  TradingApp
//
//  Data models for Spotlight Search results
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "TradingAppTypes.h"
#import "CommonTypes.h"        // ← AGGIUNGI QUESTA LINEA
#import "SpotlightCategoryButton.h"  // ← AGGIUNGI QUESTA LINEA


NS_ASSUME_NONNULL_BEGIN

#pragma mark - Symbol Search Result

@interface SymbolSearchResult : NSObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong, nullable) NSString *companyName;
@property (nonatomic, assign) DataSourceType sourceType;
@property (nonatomic, strong, nullable) NSString *exchange;
@property (nonatomic, assign) double relevanceScore; // For sorting

/**
 * Create symbol search result
 * @param symbol Stock symbol
 * @param companyName Company name (optional)
 * @param sourceType Data source that provided this result
 * @return Initialized result
 */
+ (instancetype)resultWithSymbol:(NSString *)symbol
                     companyName:(nullable NSString *)companyName
                      sourceType:(DataSourceType)sourceType;

/**
 * Display string for table view
 * @return Formatted string for display
 */
- (NSString *)displayString;

/**
 * Subtitle string for table view
 * @return Secondary information string
 */
- (NSString *)subtitleString;

@end

#pragma mark - Widget Option

@interface WidgetOption : NSObject

@property (nonatomic, strong) NSString *widgetName;
@property (nonatomic, strong) NSString *widgetType;
@property (nonatomic, strong, nullable) NSImage *icon;
@property (nonatomic, strong, nullable) NSString *subtitle;

/**
 * Create widget option
 * @param widgetName Display name for widget
 * @param widgetType Internal widget type identifier
 * @return Initialized widget option
 */
+ (instancetype)optionWithWidgetName:(NSString *)widgetName
                          widgetType:(NSString *)widgetType;

/**
 * Create widget option with icon
 * @param widgetName Display name for widget
 * @param widgetType Internal widget type identifier
 * @param icon Widget icon (optional)
 * @return Initialized widget option
 */
+ (instancetype)optionWithWidgetName:(NSString *)widgetName
                          widgetType:(NSString *)widgetType
                                icon:(nullable NSImage *)icon;

/**
 * Get default widget options list
 * @return Array of common widget options
 */
+ (NSArray<WidgetOption *> *)defaultWidgetOptions;

@end

#pragma mark - Spotlight Search Context

@interface SpotlightSearchContext : NSObject

@property (nonatomic, strong) NSString *searchText;
@property (nonatomic, assign) DataSourceType selectedDataSource;
@property (nonatomic, assign) SpotlightWidgetTarget selectedWidgetTarget;
@property (nonatomic, assign) BOOL isSymbolsTableActive;

/**
 * Create search context
 * @param searchText Current search text
 * @return Initialized context
 */
+ (instancetype)contextWithSearchText:(NSString *)searchText;

@end

NS_ASSUME_NONNULL_END
