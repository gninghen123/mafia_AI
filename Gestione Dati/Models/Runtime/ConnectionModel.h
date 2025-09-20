//
//  ConnectionModel.h
//  mafia_AI
//
//  Runtime model per le connections (non Core Data)
//

#import <Foundation/Foundation.h>
#import "ConnectionTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface ConnectionModel : NSObject

// Identifiers
@property (nonatomic, strong) NSString *connectionID;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong, nullable) NSString *connectionDescription;

// Simboli e direzionalità
@property (nonatomic, strong) NSArray<NSString *> *symbols;          // Legacy: tutti i simboli
@property (nonatomic, strong, nullable) NSString *sourceSymbol;      // Simbolo sorgente (per connessioni direzionali)
@property (nonatomic, strong) NSArray<NSString *> *targetSymbols;    // Simboli target
@property (nonatomic, assign) BOOL bidirectional;                    // Se true, tutti verso tutti

// Tipo e metadata
@property (nonatomic, assign) StockConnectionType connectionType;
@property (nonatomic, strong, nullable) NSString *source;            // Fonte dell'informazione
@property (nonatomic, strong, nullable) NSString *url;               // Link alla news
@property (nonatomic, strong, nullable) NSString *notes;             // Note aggiuntive
@property (nonatomic, strong) NSArray<NSString *> *tags;             // Tags per categorizzazione

// Date
@property (nonatomic, strong) NSDate *creationDate;
@property (nonatomic, strong) NSDate *lastModified;
@property (nonatomic, assign) BOOL isActive;

// AI Summary System
@property (nonatomic, strong, nullable) NSString *originalSummary;   // Summary generato da AI
@property (nonatomic, strong, nullable) NSString *manualSummary;     // Summary inserito manualmente
@property (nonatomic, assign) ConnectionSummarySource summarySource;

// Connection Strength con Decay
@property (nonatomic, assign) double initialStrength;                // Forza iniziale (0.0-1.0)
@property (nonatomic, assign) double currentStrength;                // Forza attuale (calcolata)
@property (nonatomic, assign) double decayRate;                      // Velocità di decadimento
@property (nonatomic, assign) double minimumStrength;                // Soglia minima
@property (nonatomic, strong, nullable) NSDate *strengthHorizon;     // Data target per il decay
@property (nonatomic, assign) BOOL autoDelete;                       // Auto-cancellazione se sotto soglia
@property (nonatomic, strong, nullable) NSDate *lastStrengthUpdate;  // Ultimo calcolo della forza

// Initializers
- (instancetype)init;
- (instancetype)initWithSymbols:(NSArray<NSString *> *)symbols
                            type:(StockConnectionType)type
                           title:(NSString *)title;

// Direzionalità helpers
- (instancetype)initDirectionalFromSymbol:(NSString *)sourceSymbol
                                toSymbols:(NSArray<NSString *> *)targetSymbols
                                     type:(StockConnectionType)type
                                    title:(NSString *)title;

- (instancetype)initBidirectionalWithSymbols:(NSArray<NSString *> *)symbols
                                         type:(StockConnectionType)type
                                        title:(NSString *)title;

// Utility methods
- (NSArray<NSString *> *)allInvolvedSymbols;                         // Tutti i simboli coinvolti
- (BOOL)involvesSymbol:(NSString *)symbol;                           // Se coinvolge un simbolo specifico
- (NSArray<NSString *> *)getRelatedSymbolsForSymbol:(NSString *)symbol; // Simboli correlati a uno specifico

// Summary methods
- (NSString *)effectiveSummary;                                      // Summary da usare (priorità: manual > AI > description)
- (BOOL)hasSummary;                                                  // Se ha almeno un summary
- (void)setAISummary:(NSString *)summary;                          // Imposta summary AI
- (void)setManualSummary:(NSString *)summary;                      // Imposta summary manuale

// Strength calculation
- (void)updateCurrentStrength;                                      // Calcola forza attuale basata sul decay
- (double)calculateStrengthForDate:(NSDate *)date;                  // Calcola forza per una data specifica
- (BOOL)shouldAutoDelete;                                           // Se deve essere auto-cancellata
- (NSInteger)daysUntilMinimumStrength;                              // Giorni rimanenti prima del minimo

// Display methods
- (NSString *)typeDisplayString;                                    // Stringa del tipo per UI
- (NSString *)strengthDisplayString;                                // Stringa della forza per UI
- (NSColor *)typeColor;                                             // Colore per il tipo
- (NSString *)typeIcon;                                             // Icona SF Symbol per il tipo

// Conversion to/from Core Data
- (NSDictionary *)toDictionary;                                     // Per serializzazione
- (void)updateFromDictionary:(NSDictionary *)dict;                 // Per deserializzazione

@end

NS_ASSUME_NONNULL_END
