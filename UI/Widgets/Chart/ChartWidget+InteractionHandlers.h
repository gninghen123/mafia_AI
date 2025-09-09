//
//  ChartWidget+InteractionHandlers.h
//  TradingApp
//
//  Centralized interaction handling to avoid code duplication
//
#import "ChartWidget.h"


#pragma mark - INTERACTION HANDLERS ARCHITECTURE

typedef NS_OPTIONS(NSUInteger, ChartInvalidationFlags) {
    ChartInvalidationNone           = 0,
    ChartInvalidationData           = 1 << 0,  // Dati cambiati (symbol/timeframe/range)
    ChartInvalidationIndicators     = 1 << 1,  // Indicatori da ricalcolare
    ChartInvalidationViewport       = 1 << 2,  // Viewport/zoom cambiato
    ChartInvalidationAlerts         = 1 << 3,  // Alert da ricaricare
    ChartInvalidationObjects        = 1 << 4,  // Oggetti da ricaricare
    ChartInvalidationTemplate       = 1 << 5,  // Template cambiato
    ChartInvalidationUI             = 1 << 6,  // UI controls da aggiornare
    
    // Combinazioni comuni
    ChartInvalidationSymbolChange   = ChartInvalidationData | ChartInvalidationIndicators |
                                     ChartInvalidationViewport | ChartInvalidationAlerts |
                                     ChartInvalidationObjects | ChartInvalidationUI,
                                     
    ChartInvalidationTimeframeChange = ChartInvalidationData | ChartInvalidationIndicators |
                                      ChartInvalidationViewport | ChartInvalidationUI,
                                      
    ChartInvalidationDataRangeChange = ChartInvalidationData | ChartInvalidationIndicators | ChartInvalidationUI,
    
    ChartInvalidationTemplateChange = ChartInvalidationIndicators | ChartInvalidationUI
};

@interface ChartWidget (InteractionHandlers)

#pragma mark - PRIMARY INTERACTION HANDLERS

/**
 * Handle symbol change with all necessary coordination
 * @param newSymbol The new symbol to load
 * @param forceReload Force reload even if symbol is the same
 */
- (void)handleSymbolChange:(NSString *)newSymbol forceReload:(BOOL)forceReload;

/**
 * Handle timeframe change
 * @param newTimeframe The new timeframe
 */
- (void)handleTimeframeChange:(BarTimeframe)newTimeframe;

/**
 * Handle data range change
 * @param newDays Number of days for the new range
 * @param isExtension YES if we're extending existing data, NO if completely new range
 */
- (void)handleDataRangeChange:(NSInteger)newDays isExtension:(BOOL)isExtension;

/**
 * Handle template change
 * @param newTemplate The new chart template
 */
- (void)handleTemplateChange:(ChartTemplateModel *)newTemplate;

/**
 * Handle trading hours mode change
 * @param newMode The new trading hours mode
 */
- (void)handleTradingHoursChange:(ChartTradingHours)newMode;

/**
 * Handle static mode toggle
 * @param isStatic YES to enable static mode, NO to disable
 */
- (void)handleStaticModeToggle:(BOOL)isStatic;

#pragma mark - COMMON PROCESSING NODES

/**
 * SNODO COMUNE 1: Process new historical data
 * Called by: symbol change, timeframe change, data range change, trading hours change
 */
- (void)processNewHistoricalData:(NSArray<HistoricalBarModel *> *)newData
                   invalidations:(ChartInvalidationFlags)flags;

/**
 * SNODO COMUNE 2: Process indicator recalculation
 * Called by: new data, template change
 */
- (void)processIndicatorRecalculation:(ChartInvalidationFlags)flags;

/**
 * SNODO COMUNE 3: Process viewport update
 * Called by: new data, zoom operations, data range extension
 */
- (void)processViewportUpdate:(ChartInvalidationFlags)flags;

/**
 * SNODO COMUNE 4: Process UI synchronization
 * Called by: all changes that affect UI controls
 */
- (void)processUIUpdate:(ChartInvalidationFlags)flags;

#pragma mark - COORDINATION HELPERS

/**
 * Coordinate symbol-related components (alerts, objects)
 */
- (void)coordinateSymbolDependencies:(NSString *)newSymbol;

/**
 * Update UI controls based on current state
 */
- (void)updateUIControlsForCurrentState;

/**
 * Apply smart invalidation based on flags
 */
- (void)applyInvalidations:(ChartInvalidationFlags)flags;

@end
