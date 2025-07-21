//
//  WidgetTypeManager.m
//  TradingApp
//

#import "WidgetTypeManager.h"
#import "BaseWidget.h"
#import "QuoteWidget.h"
#import "ConnectionStatusWidget.h"
#import "WatchlistWidget.h"
#import "CHChartWidget.h"  // FIX: Aggiunto import per CHChartWidget
#import "AlertWidget.h"
#import "MultiChartWidget.h"
#import "MiniChart.h"
#import "GeneralMarketWidget.h"

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
            @"Chart Widget",        // FIX: Aggiunto Chart Widget generico
            @"MultiChart Widget",  // <-- AGGIUNGI QUESTA LINEA
            @"Candlestick Chart",
            @"Line Chart",
            @"Bar Chart",
            @"Market Depth",
            @"Volume Profile",
            @"Heatmap"
        ],
        @"Trading": @[
            @"Order Entry",
            @"Order Book",
            @"Positions",
            @"Open Orders",
            @"Trade History",
            @"P&L Summary"
        ],
        @"Analysis": @[
            @"Technical Indicators",
            @"Scanner",
            @"Alerts",
            @"Strategy Tester",
            @"Correlation Matrix",
            @"Options Chain"
        ],
        @"Information": @[
            @"Quote",
            @"Watchlist",
            @"General Market",     // <-- AGGIUNGI QUESTA LINEA
            @"News Feed",
            @"Economic Calendar",
            @"Market Overview",
            @"Symbol Info",
            @"Time & Sales"
        ],
        @"Tools": @[
            @"Connection Status",
            @"Calculator",
            @"Notes",
            @"Risk Manager",
            @"Position Sizer",
            @"Market Clock",
            @"Performance Analytics"
        ]
    };
    
    // Map widget types to their implementation classes
    NSMutableDictionary *typeToClass = [NSMutableDictionary dictionary];
    
    // FIX: Map specific widget types to their classes
    typeToClass[@"Quote"] = [QuoteWidget class];
    typeToClass[@"Watchlist"] = [WatchlistWidget class];
    typeToClass[@"Connection Status"] = [ConnectionStatusWidget class];
    typeToClass[@"MultiChart Widget"] = [MultiChartWidget class];  // <-- AGGIUNGI QUESTA LINEA
    typeToClass[@"General Market"] = [GeneralMarketWidget class];

    // FIX: Map chart types to CHChartWidget
    typeToClass[@"Chart Widget"] = [CHChartWidget class];
    typeToClass[@"Candlestick Chart"] = [CHChartWidget class];
    typeToClass[@"Line Chart"] = [CHChartWidget class];
    typeToClass[@"Bar Chart"] = [CHChartWidget class];
    typeToClass[@"Market Depth"] = [CHChartWidget class];
    typeToClass[@"Volume Profile"] = [CHChartWidget class];
    typeToClass[@"Heatmap"] = [CHChartWidget class];
    typeToClass[@"Alerts"] = [AlertWidget class];

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
        // FIX: Icone per i chart widgets
        @"Chart Widget": @"chart.xyaxis.line",
        @"Candlestick Chart": @"chart.bar",
        @"Line Chart": @"chart.line.uptrend.xyaxis",
        @"Bar Chart": @"chart.bar.xaxis",
        @"Market Depth": @"chart.bar.doc.horizontal",
        @"Volume Profile": @"chart.bar.fill",
        @"Heatmap": @"square.grid.3x3.fill.square",
        @"MultiChart Widget": @"square.grid.3x3",  // <-- AGGIUNGI QUESTA LINEA

        @"Order Entry": @"plus.square",
        @"Order Book": @"book",
        @"Positions": @"briefcase",
        @"Open Orders": @"doc.text",
        @"Trade History": @"clock",
        @"P&L Summary": @"dollarsign.circle",
        
        @"Technical Indicators": @"waveform.path.ecg",
        @"Scanner": @"magnifyingglass",
        @"Alerts": @"bell",
        @"Strategy Tester": @"play.rectangle",
        @"Correlation Matrix": @"square.grid.3x3",
        @"Options Chain": @"list.bullet.indent",
        
        @"General Market": @"list.bullet.rectangle",
        @"Quote": @"dollarsign.circle",
        @"Watchlist": @"star.fill",
        @"News Feed": @"newspaper",
        @"Economic Calendar": @"calendar",
        @"Market Overview": @"globe",
        @"Symbol Info": @"info.circle",
        @"Time & Sales": @"list.dash",
        
        @"Calculator": @"plus.slash.minus",
        @"Notes": @"note.text",
        @"Risk Manager": @"shield",
        @"Position Sizer": @"ruler",
        @"Market Clock": @"clock.fill",
        @"Performance Analytics": @"chart.pie",
        @"Connection Status": @"network"
    };
}

#pragma mark - Public Methods

- (NSString *)correctNameForType:(NSString *)type {
    // Cerca il nome corretto (case-sensitive) per il tipo fornito
    NSArray *availableTypes = [self availableWidgetTypes];
    
    // Prima prova una corrispondenza esatta
    if ([availableTypes containsObject:type]) {
        return type;
    }
    
    // Poi prova una corrispondenza case-insensitive
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF ==[cd] %@", type];
    NSArray *matches = [availableTypes filteredArrayUsingPredicate:predicate];
    
    if (matches.count > 0) {
        return matches[0]; // Restituisce la prima corrispondenza con la giusta capitalizzazione
    }
    
    // Se non trovato, restituisce il tipo originale
    return type;
}

- (Class)classForWidgetType:(NSString *)type {
    // Questo è un alias per widgetClassForType: per mantenere compatibilità
    return [self widgetClassForType:type];
}
- (NSArray<NSString *> *)availableWidgetTypes {
    NSMutableArray *allTypes = [NSMutableArray array];
    for (NSArray *types in self.widgetCategories.allValues) {
        [allTypes addObjectsFromArray:types];
    }
    NSArray *sortedTypes = [allTypes sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    return sortedTypes;
}

- (NSArray<NSString *> *)widgetTypesForCategory:(NSString *)category {
    return self.widgetCategories[category] ?: @[];
}

- (NSDictionary<NSString *, NSArray<NSString *> *> *)widgetTypesByCategory {
    return [self.widgetCategories copy];
}

- (Class)widgetClassForType:(NSString *)type {
    Class widgetClass = self.widgetTypeToClass[type] ?: [BaseWidget class];
    NSLog(@"widgetClassForType '%@' returning: %@", type, widgetClass);
    return widgetClass;
}

- (NSString *)iconNameForWidgetType:(NSString *)type {
    return self.widgetTypeToIcon[type] ?: @"square.dashed";
}

@end
