//
//  WidgetTypeManager.m
//  TradingApp
//
#import "APIPlaygroundWidget.h"
#import "WidgetTypeManager.h"
#import "BaseWidget.h"
#import "QuoteWidget.h"
#import "ConnectionStatusWidget.h"
#import "WatchlistWidget.h"
#import "ChartWidget.h"
#import "AlertWidget.h"
#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "ConnectionsWidget.h"
#import "SymbolDataBase/SymbolDataBaseWidget.h"
#import "SeasonalChartWidget.h"
#import "TickChartWidget.h"
#import "StorageManagementWidget.h"
#import "LegacyDataConverterWidget.h"
#import "ChartPatternLibraryWidget.h"
#import "PortfolioWidget.h"  
#import "IBKRTestWidget.h"
#import "NewsWidget.h"


@interface WidgetTypeManager ()
@property (nonatomic, strong) NSDictionary<NSString *, NSArray<NSString *> *> *widgetCategories;
@property (nonatomic, strong) NSDictionary<NSString *, Class> *widgetTypeToClass;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *widgetTypeToIcon;
@end

@implementation WidgetTypeManager

+ (instancetype)sharedManager {
    static WidgetTypeManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupWidgetTypes];
    }
    return self;
}

- (void)setupWidgetTypes {
    // Define widget categories and types
    self.widgetCategories = @{
        @"Charts": @[
            @"Chart Widget",
            @"MultiChart Widget",
            @"Candlestick Chart",
            @"Line Chart",
            @"Bar Chart",
            @"Market Depth",
            @"Volume Profile",
            @"Heatmap",
            @"Seasonal Chart",       // NUOVO: Aggiunto SeasonalChart
            @"Tick Chart"           // NEW: Added TickChart
        ],
        @"Trading": @[
            @"Order Entry",
            @"Order Book",
            @"Positions",
            @"Open Orders",
            @"Trade History",
            @"P&L Summary",
            @"Portfolio"     // ✅ NUOVO: Aggiunto nella categoria Trading

        ],
        @"Analysis": @[
            @"Technical Indicators",
            @"Scanner",
            @"Alerts",
            @"Alerts",
            @"Strategy Tester",
            @"Correlation Matrix",
            @"Options Chain",
            @"Pattern Chart Library"  // ✅ AGGIUNTO: ChartPatternLibrary nella categoria Analysis
        ],
        @"Information": @[
            @"Quote",
            @"Watchlist",
            @"General Market",
            @"News",
            @"Economic Calendar",
            @"Market Overview",
            @"Symbol Info",
            @"Time & Sales",
            @"Connections",
            @"SymbolDatabase"
        ],
        @"Tools": @[
            @"Connection Status",
            @"Calculator",
            @"Notes",
            @"Risk Manager",
            @"Position Sizer",
            @"Market Clock",
            @"Performance Analytics",
            @"API Playground",
            @"Storage Management",
            @"LegacyDataConverter",
            @"IBKR Test Widget"  // NUOVO


        ]
    };
    
    // Map widget types to their implementation classes
    NSMutableDictionary *typeToClass = [NSMutableDictionary dictionary];
    
    // FIX: Map specific widget types to their classes
    typeToClass[@"Quote"] = [QuoteWidget class];
    typeToClass[@"Watchlist"] = [WatchlistWidget class];
    typeToClass[@"Connection Status"] = [ConnectionStatusWidget class];
    typeToClass[@"MultiChart Widget"] = [MultiChartWidget class];
    typeToClass[@"Connections"] = [ConnectionsWidget class];
    typeToClass[@"SymbolDatabase"] = [SymbolDatabaseWidget class];
    typeToClass[@"Alerts"] = [AlertWidget class];
    typeToClass[@"Alert"] = [AlertWidget class];
    typeToClass[@"Seasonal Chart"] = [SeasonalChartWidget class];
    typeToClass[@"Tick Chart"] = [TickChartWidget class];
    typeToClass[@"API Playground"] = [APIPlaygroundWidget class];
    typeToClass[@"Chart Widget"] = [ChartWidget class];
    typeToClass[@"Candlestick Chart"] = [ChartWidget class];
    typeToClass[@"Line Chart"] = [ChartWidget class];
    typeToClass[@"Bar Chart"] = [ChartWidget class];
    typeToClass[@"Market Depth"] = [ChartWidget class];
    typeToClass[@"Volume Profile"] = [ChartWidget class];
    typeToClass[@"Heatmap"] = [ChartWidget class];
    typeToClass[@"Storage Management"] = [StorageManagementWidget class];
    typeToClass[@"LegacyDataConverter"] = [LegacyDataConverterWidget class];
    typeToClass[@"Pattern Chart Library"] = [ChartPatternLibraryWidget class];
    typeToClass[@"Portfolio"] = [PortfolioWidget class];
    typeToClass[@"IBKR Test Widget"]= [IBKRTestWidget class];
    typeToClass[@"News"] = [NewsWidget class];

    // Map all other types to BaseWidget for now
    for (NSArray *types in self.widgetCategories.allValues) {
        for (NSString *type in types) {
            if (!typeToClass[type]) {
                typeToClass[type] = [BaseWidget class];
            }
        }
    }
    self.widgetTypeToClass = [typeToClass copy];
    
    // Map widget types to icons (using SF Symbols)
    self.widgetTypeToIcon = @{
        @"Chart Widget": @"chart.xyaxis.line",
        @"Seasonal Chart": @"chart.bar.xaxis",
        @"Candlestick Chart": @"chart.bar",
        @"Line Chart": @"chart.line.uptrend.xyaxis",
        @"Bar Chart": @"chart.bar.xaxis",
        @"Market Depth": @"chart.bar.doc.horizontal",
        @"Volume Profile": @"chart.bar.fill",
        @"Heatmap": @"square.grid.3x3.fill.square",
        @"MultiChart Widget": @"square.grid.3x3",
        @"Connections": @"link",
        @"SymbolDatabase":@"tray.2",
        @"Tick Chart": @"list.bullet.rectangle",
        @"Order Entry": @"plus.square",
        @"Order Book": @"book",
        @"Positions": @"briefcase",
        @"Open Orders": @"doc.text",
        @"Trade History": @"clock",
        @"P&L Summary": @"dollarsign.circle",
        @"API Playground": @"briefcase",
        @"Storage Management": @"externaldrive.fill",
        @"Pattern Chart Library": @"square.grid.3x3.bottomleft.fill",  // ✅ AGGIUNTO: Icona per ChartPatternLibrary
        @"Portfolio": @"briefcase.fill",  // ✅ NUOVO: Icona per Portfolio Widget
        @"IBKR Test Widget": @"testtube.2",
        @"News": @"newspaper",

        @"Technical Indicators": @"waveform.path.ecg",
        @"Scanner": @"magnifyingglass",
        @"Alerts": @"bell",
        @"Strategy Tester": @"play.rectangle",
        @"Correlation Matrix": @"square.grid.3x3",
        @"Options Chain": @"list.bullet.indent",
        
        @"General Market": @"list.bullet.rectangle",
        @"Quote": @"textformat.123",
        @"Watchlist": @"list.bullet.rectangle",
        @"News Feed": @"newspaper",
        @"Economic Calendar": @"calendar",
        @"Market Overview": @"chart.line.uptrend.xyaxis",
        @"Symbol Info": @"info.circle",
        @"Time & Sales": @"clock",
        
        @"Connection Status": @"wifi",
        @"Calculator": @"plusminus",
        @"Notes": @"note.text",
        @"Risk Manager": @"shield",
        @"Position Sizer": @"ruler",
        @"Market Clock": @"clock",
        @"Performance Analytics": @"chart.bar.xaxis",
        @"LegacyDataConverter": @"arrow.up.arrow.down.circle"
    };
}

#pragma mark - Public Methods

- (NSArray<NSString *> *)availableWidgetTypes {
    NSMutableArray *types = [NSMutableArray array];
    for (NSArray *categoryTypes in self.widgetCategories.allValues) {
        [types addObjectsFromArray:categoryTypes];
    }
    return [types copy];
}

- (NSArray<NSString *> *)widgetTypesForCategory:(NSString *)category {
    return self.widgetCategories[category] ?: @[];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)widgetTypesByCategory {
    return [self.widgetCategories copy];
}

- (Class)widgetClassForType:(NSString *)type {
    Class widgetClass = self.widgetTypeToClass[type];
    return widgetClass ?: [BaseWidget class];
}

- (NSString *)iconNameForWidgetType:(NSString *)type {
    return self.widgetTypeToIcon[type] ?: @"questionmark.square";
}

// FIX: Aggiunti metodi mancanti utilizzati in BaseWidget.m
- (NSString *)correctNameForType:(NSString *)type {
    // Return the type as is if it exists in our categories
    for (NSArray *types in self.widgetCategories.allValues) {
        if ([types containsObject:type]) {
            return type;
        }
    }
    // If not found, return the original type
    return type;
}

- (Class)classForWidgetType:(NSString *)type {
    return [self widgetClassForType:type];
}

@end
