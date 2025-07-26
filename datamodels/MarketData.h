//
//  MarketData.h
//  mafia_AI
//
//  Modello per rappresentare dati di mercato real-time
//  Usato come modello intermedio prima di salvare in Core Data
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MarketData : NSObject

// Identificazione
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong, nullable) NSString *name;
@property (nonatomic, strong, nullable) NSString *exchange;

// Prezzi
@property (nonatomic, strong, nullable) NSNumber *last;          // Ultimo prezzo
@property (nonatomic, strong, nullable) NSNumber *bid;           // Prezzo bid
@property (nonatomic, strong, nullable) NSNumber *ask;           // Prezzo ask
@property (nonatomic, strong, nullable) NSNumber *open;          // Apertura
@property (nonatomic, strong, nullable) NSNumber *high;          // Massimo
@property (nonatomic, strong, nullable) NSNumber *low;           // Minimo
@property (nonatomic, strong, nullable) NSNumber *previousClose; // Chiusura precedente
@property (nonatomic, strong, nullable) NSNumber *close;         // Chiusura

// Variazioni
@property (nonatomic, strong, nullable) NSNumber *change;        // Variazione assoluta
@property (nonatomic, strong, nullable) NSNumber *changePercent; // Variazione percentuale

// Volume
@property (nonatomic, strong, nullable) NSNumber *volume;        // Volume
@property (nonatomic, strong, nullable) NSNumber *avgVolume;     // Volume medio

// Altri dati
@property (nonatomic, strong, nullable) NSNumber *marketCap;     // Capitalizzazione
@property (nonatomic, strong, nullable) NSNumber *pe;            // P/E ratio
@property (nonatomic, strong, nullable) NSNumber *eps;           // Earnings per share
@property (nonatomic, strong, nullable) NSNumber *beta;          // Beta

// Timestamp
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) BOOL isMarketOpen;

// Inizializzatore
- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

// Conversione
- (NSDictionary *)toDictionary;

// Helper methods
- (BOOL)isGainer;
- (BOOL)isLoser;
- (NSString *)formattedPrice;
- (NSString *)formattedChange;
- (NSString *)formattedChangePercent;

@end

NS_ASSUME_NONNULL_END
