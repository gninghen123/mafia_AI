//
//  WidgetTypeManager.m
//  TradingApp
//
#import "APIPlaygroundWidget.h"
#import "WidgetTypeManager.h"
#import "BaseWidget.h"
#import "ConnectionStatusWidget.h"
#import "WatchlistWidget.h"
#import "ChartWidget.h"
#import "AlertWidget.h"
#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "ConnectionsWidget.h"
#import "SymbolDataBaseWidget.h"
#import "SeasonalChartWidget.h"
#import "TickChartWidget.h"
#import "StorageManagementWidget.h"
#import "LegacyDataConverterWidget.h"
#import "ChartPatternLibraryWidget.h"
#import "PortfolioWidget.h"  
#import "IBKRTestWidget.h"
#import "NewsWidget.h"
#import "PineScriptEditorWidget.h"
#import "screenerwidget.h"
#import "stooqscreenerwidget.h"
#import "ComparisonChartWidget.h"

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
            @"Chart",
            @"MultiChart",
            @"Comparison Chart",
            @"Seasonal Chart",       // NUOVO: Aggiunto SeasonalChart
            @"Tick Chart"           // NEW: Added TickChart
        ],
        @"Information": @[
            @"Watchlist",
            @"Quote",
            @"News",
            @"Symbol Info",
            @"Time & Sales",
            @"Connections",
            @"SymbolDatabase"
        ],
        @"Analysis": @[
            @"Technical Indicators",
            @"Screener",
            @"Stooq Screener",
            @"Alerts",
            @"Strategy Tester",
            @"Pattern Chart Library"  // ✅ AGGIUNTO: ChartPatternLibrary nella categoria Analysis
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
       @"Tools": @[
            @"Connection Status",
            @"Notes",
            @"Risk Manager",
            @"API Playground",
            @"Storage Management",
            @"LegacyDataConverter",
            @"PineScript Editor",
            @"IBKR Test"  // NUOVO
        ]
    };
    
    // Map widget types to their implementation classes
    NSMutableDictionary *typeToClass = [NSMutableDictionary dictionary];
    
    // FIX: Map specific widget types to their classes
    typeToClass[@"Watchlist"] = [WatchlistWidget class];
    typeToClass[@"Connection Status"] = [ConnectionStatusWidget class];
    typeToClass[@"MultiChart"] = [MultiChartWidget class];
    typeToClass[@"Connections"] = [ConnectionsWidget class];
    typeToClass[@"SymbolDatabase"] = [SymbolDatabaseWidget class];
    typeToClass[@"Alerts"] = [AlertWidget class];
    typeToClass[@"Seasonal Chart"] = [SeasonalChartWidget class];
    typeToClass[@"Tick Chart"] = [TickChartWidget class];
    typeToClass[@"API Playground"] = [APIPlaygroundWidget class];
    typeToClass[@"Chart"] = [ChartWidget class];
    typeToClass[@"Storage Management"] = [StorageManagementWidget class];
    typeToClass[@"LegacyDataConverter"] = [LegacyDataConverterWidget class];
    typeToClass[@"Pattern Chart Library"] = [ChartPatternLibraryWidget class];
    typeToClass[@"Portfolio"] = [PortfolioWidget class];
    typeToClass[@"IBKR Test"]= [IBKRTestWidget class];
    typeToClass[@"News"] = [NewsWidget class];
    typeToClass[@"Screener"] = [ScreenerWidget class];
    typeToClass[@"Stooq Screener"] = [StooqScreenerWidget class];
    typeToClass[@"PineScript Editor"] = [PineScriptEditorWidget class];
    typeToClass[@"Comparison Chart"] = [ComparisonChartWidget class];

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
        @"Chart": @"chart.xyaxis.line",
        @"Watchlist": @"list.bullet.rectangle",
        @"Seasonal Chart": @"chart.bar.xaxis",
        @"MultiChart": @"square.grid.3x3",
        @"Connections": @"link",
        @"Comparison Chart": @"chart.bar.fill",
        @"Tick Chart": @"list.bullet.rectangle",
        @"Pattern Chart Library": @"square.grid.3x3.bottomleft.fill",
        @"News": @"newspaper",

        @"Screener": @"magnifyingglass",
        @"Stooq Screener": @"magnifyingglass",
        @"Alerts": @"bell",
        @"Strategy Tester": @"play.rectangle",
        @"Correlation Matrix": @"square.grid.3x3",
        
        @"Economic Calendar": @"calendar",
        @"Symbol Info": @"info.circle",
        @"Technical Indicators": @"waveform.path.ecg",
        @"SymbolDatabase":@"tray.2",
        @"Storage Management": @"externaldrive.fill",
        @"Portfolio": @"briefcase.fill",

        
        @"Connection Status": @"wifi",
        @"API Playground": @"briefcase",
        @"IBKR Test Widget": @"testtube.2",
        @"PineScript Editor":@"pine",
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
