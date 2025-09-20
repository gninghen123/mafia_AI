//
//  ConnectionTypes.h
//  mafia_AI
//
//  Definizioni per il sistema Connections
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>  

NS_ASSUME_NONNULL_BEGIN

// Tipi di connessione
typedef NS_ENUM(NSInteger, StockConnectionType) {
    StockConnectionTypeNews = 0,           // Connessione basata su news
    StockConnectionTypePersonalNote = 1,   // Nota personale
    StockConnectionTypeSympathy = 2,       // Movimento in sympathy
    StockConnectionTypeCollaboration = 3,  // Collaborazione aziendale
    StockConnectionTypeMerger = 4,         // Fusione/Acquisizione
    StockConnectionTypePartnership = 5,    // Partnership
    StockConnectionTypeSupplier = 6,       // Relazione fornitore-cliente
    StockConnectionTypeCompetitor = 7,     // Competitor
    StockConnectionTypeCorrelation = 8,    // Correlazione osservata
    StockConnectionTypeSector = 9,         // Stesso settore
    StockConnectionTypeCustom = 99         // Tipo personalizzato
};

// Sorgente del summary
typedef NS_ENUM(NSInteger, ConnectionSummarySource) {
    ConnectionSummarySourceNone = 0,       // Nessun summary
    ConnectionSummarySourceAI = 1,         // Generato da AI
    ConnectionSummarySourceManual = 2,     // Inserito manualmente
    ConnectionSummarySourceBoth = 3        // Entrambi (AI + editato manualmente)
};

// Algoritmo di decay per la forza della connessione
typedef NS_ENUM(NSInteger, ConnectionDecayType) {
    ConnectionDecayTypeNone = 0,           // Nessun decay
    ConnectionDecayTypeLinear = 1,         // Decay lineare
    ConnectionDecayTypeExponential = 2,    // Decay esponenziale
    ConnectionDecayTypeStep = 3            // Decay a gradini
};

// Utility functions per conversioni string
NSString *StringFromConnectionType(StockConnectionType type);
StockConnectionType ConnectionTypeFromString(NSString *string);

NSString *StringFromSummarySource(ConnectionSummarySource source);
ConnectionSummarySource SummarySourceFromString(NSString *string);

NSString *StringFromDecayType(ConnectionDecayType type);
ConnectionDecayType DecayTypeFromString(NSString *string);

// Icone SF Symbols per ogni tipo
NSString *IconForConnectionType(StockConnectionType type);

// Colori suggeriti per ogni tipo
NSColor *ColorForConnectionType(StockConnectionType type);

NS_ASSUME_NONNULL_END
