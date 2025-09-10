//
//  SpotlightModels.m
//  TradingApp
//
//  Data models implementation for Spotlight Search
//

#import "SpotlightModels.h"
#import "SpotlightCategoryButton.h"

#pragma mark - Symbol Search Result Implementation

@implementation SymbolSearchResult

+ (instancetype)resultWithSymbol:(NSString *)symbol
                     companyName:(nullable NSString *)companyName
                      sourceType:(DataSourceType)sourceType {
    SymbolSearchResult *result = [[SymbolSearchResult alloc] init];
    result.symbol = symbol.uppercaseString;
    result.companyName = companyName;
    result.sourceType = sourceType;
    result.relevanceScore = 1.0; // Default relevance
    return result;
}

- (NSString *)displayString {
    if (self.companyName && self.companyName.length > 0) {
        return [NSString stringWithFormat:@"%@ - %@", self.symbol, self.companyName];
    } else {
        return self.symbol;
    }
}

- (NSString *)subtitleString {
    NSString *sourceName = [SpotlightCategoryButton displayNameForDataSource:self.sourceType];
    
    if (self.exchange && self.exchange.length > 0) {
        return [NSString stringWithFormat:@"%@ • %@", sourceName, self.exchange];
    } else {
        return sourceName;
    }
}

@end

#pragma mark - Widget Option Implementation

@implementation WidgetOption

+ (instancetype)optionWithWidgetName:(NSString *)widgetName
                          widgetType:(NSString *)widgetType {
    return [self optionWithWidgetName:widgetName widgetType:widgetType icon:nil];
}

+ (instancetype)optionWithWidgetName:(NSString *)widgetName
                          widgetType:(NSString *)widgetType
                                icon:(nullable NSImage *)icon {
    WidgetOption *option = [[WidgetOption alloc] init];
    option.widgetName = widgetName;
    option.widgetType = widgetType;
    option.icon = icon;
    return option;
}

+ (NSArray<WidgetOption *> *)defaultWidgetOptions {
    return @[
        [WidgetOption optionWithWidgetName:@"Chart" widgetType:@"Chart Widget"],
        [WidgetOption optionWithWidgetName:@"Watchlist" widgetType:@"Watchlist"],
        [WidgetOption optionWithWidgetName:@"Quote" widgetType:@"Quote"],
        [WidgetOption optionWithWidgetName:@"News" widgetType:@"News"],
        [WidgetOption optionWithWidgetName:@"Alerts" widgetType:@"Alerts"],
        [WidgetOption optionWithWidgetName:@"Connections" widgetType:@"Connections"],
        [WidgetOption optionWithWidgetName:@"Calculator" widgetType:@"Calculator"],
        [WidgetOption optionWithWidgetName:@"Connection Status" widgetType:@"Connection Status"],
        [WidgetOption optionWithWidgetName:@"API Playground" widgetType:@"API Playground"],
        [WidgetOption optionWithWidgetName:@"Seasonal Chart" widgetType:@"Seasonal Chart"]
    ];
}

@end

#pragma mark - Spotlight Search Context Implementation

@implementation SpotlightSearchContext

+ (instancetype)contextWithSearchText:(NSString *)searchText {
    SpotlightSearchContext *context = [[SpotlightSearchContext alloc] init];
    context.searchText = searchText;
    context.selectedDataSource = DataSourceTypeSchwab; // Default
    context.selectedWidgetTarget = SpotlightWidgetTargetCenterPanel; // Default
    context.isSymbolsTableActive = YES; // Start with symbols table active
    return context;
}

@end
