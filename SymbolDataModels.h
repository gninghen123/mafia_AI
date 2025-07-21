//
//  SymbolDataModels.h
//  TradingApp
//
//  Modelli di dati per il database centralizzato
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

// Forward declarations per evitare import circolari
@class SymbolData;
@class TagData;
@class NoteData;
@class AlertData;
@class NewsData;
@class TradingConfigData;

// Protocol per oggetti che possono essere salvati/caricati
@protocol DataPersistable <NSObject>
- (NSDictionary *)serialize;
- (instancetype)initWithDictionary:(NSDictionary *)dict;
@end

// Update types (duplicato da SymbolDataHub.h per evitare import circolare)
typedef NS_ENUM(NSInteger, SymbolUpdateType) {
    SymbolUpdateTypeTags,
    SymbolUpdateTypeNotes,
    SymbolUpdateTypeAlerts,
    SymbolUpdateTypeNews,
    SymbolUpdateTypeConfig,
    SymbolUpdateTypeCustomData,
    SymbolUpdateTypeAll
};

#pragma mark - AlertData Enums

typedef NS_ENUM(NSInteger, AlertType) {
    AlertTypePriceAbove,
    AlertTypePriceBelow,
    AlertTypeVolumeAbove,
    AlertTypePercentChange,
    AlertTypeTechnicalIndicator,
    AlertTypePattern,
    AlertTypeCustom
};

typedef NS_ENUM(NSInteger, AlertStatus) {
    AlertStatusActive,
    AlertStatusTriggered,
    AlertStatusDisabled,
    AlertStatusExpired
};

#pragma mark - SymbolData

@interface SymbolData : NSManagedObject

@property (nonatomic, retain) NSString *symbol;
@property (nonatomic, retain) NSString * _Nullable fullName;
@property (nonatomic, retain) NSString * _Nullable exchange;
@property (nonatomic, retain) NSDate *dateAdded;
@property (nonatomic, retain) NSDate *lastModified;

// Relazioni
@property (nonatomic, retain) NSSet<TagData *> *tags;
@property (nonatomic, retain) NSSet<NoteData *> *notes;
@property (nonatomic, retain) NSSet<AlertData *> *alerts;
@property (nonatomic, retain) NSSet<NewsData *> *savedNews;
@property (nonatomic, retain) TradingConfigData * _Nullable tradingConfig;

// Dati custom come JSON
@property (nonatomic, retain) NSData * _Nullable customData;

// Helper methods
- (void)addTag:(TagData *)tag;
- (void)removeTag:(TagData *)tag;
- (NSArray<NSString *> *)tagNames;

@end

#pragma mark - TagData

@interface TagData : NSManagedObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString * _Nullable colorHex;
@property (nonatomic, retain) NSDate *dateCreated;
@property (nonatomic, retain) NSSet<SymbolData *> *symbols;

@end

#pragma mark - NoteData

@interface NoteData : NSManagedObject <DataPersistable>

@property (nonatomic, retain) NSString *content;
@property (nonatomic, retain) NSDate *timestamp;
@property (nonatomic, retain) NSString * _Nullable author;
@property (nonatomic, retain) SymbolData *symbol;

@end

#pragma mark - AlertData

@interface AlertData : NSManagedObject <DataPersistable>

@property (nonatomic, retain) NSString *alertId;
@property (nonatomic) AlertType type;
@property (nonatomic) AlertStatus status;
@property (nonatomic, retain) NSDictionary *conditions;
@property (nonatomic, retain) NSString * _Nullable message;
@property (nonatomic, retain) NSDate *dateCreated;
@property (nonatomic, retain) NSDate * _Nullable dateTriggered;
@property (nonatomic, retain) NSDate * _Nullable expirationDate;
@property (nonatomic) BOOL repeating;
@property (nonatomic, retain) SymbolData *symbol;

// Helper methods
- (BOOL)isActive;
- (BOOL)shouldCheckCondition;
- (NSString *)formattedDescription;

@end

#pragma mark - NewsData

@interface NewsData : NSManagedObject <DataPersistable>

@property (nonatomic, retain) NSString *newsId;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString * _Nullable summary;
@property (nonatomic, retain) NSString * _Nullable url;
@property (nonatomic, retain) NSString * _Nullable source;
@property (nonatomic, retain) NSDate *publishDate;
@property (nonatomic, retain) NSDate *savedDate;
@property (nonatomic, retain) NSString * _Nullable sentiment; // positive, negative, neutral
@property (nonatomic, retain) SymbolData *symbol;

@end

#pragma mark - TradingConfigData

@interface TradingConfigData : NSManagedObject <DataPersistable>

// Data source preferences
@property (nonatomic, retain) NSString * _Nullable preferredDataSource;
@property (nonatomic, retain) NSString * _Nullable backupDataSource;

// Default chart settings
@property (nonatomic, retain) NSString * _Nullable defaultTimeframe;
@property (nonatomic, retain) NSString * _Nullable defaultChartType;
@property (nonatomic, retain) NSArray * _Nullable defaultIndicators;

// Trading preferences
@property (nonatomic) double defaultPositionSize;
@property (nonatomic) double stopLossPercent;
@property (nonatomic) double takeProfitPercent;
@property (nonatomic) BOOL useTrailingStop;

// Risk management
@property (nonatomic) double maxPositionSize;
@property (nonatomic) double maxDailyLoss;
@property (nonatomic) NSInteger maxOpenPositions;

// Relazione
@property (nonatomic, retain) SymbolData *symbol;

@end

#pragma mark - Helper Classes

// Classe base per dati custom futuri
@interface CustomDataObject : NSObject <DataPersistable>

@property (nonatomic, strong) NSString *dataType;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSDictionary *data;

@end

// Manager per query complesse
@interface SymbolDataQuery : NSObject

@property (nonatomic, strong) NSMutableArray<NSPredicate *> *predicates;
@property (nonatomic, strong) NSArray<NSSortDescriptor *> * _Nullable sortDescriptors;
@property (nonatomic) NSInteger limit;

+ (instancetype)query;
- (SymbolDataQuery *)withTag:(NSString *)tag;
- (SymbolDataQuery *)withTags:(NSArray<NSString *> *)tags;
- (SymbolDataQuery *)withActiveAlerts;
- (SymbolDataQuery *)modifiedSince:(NSDate *)date;
- (SymbolDataQuery *)sortedBySymbol;
- (SymbolDataQuery *)sortedByLastModified;
- (SymbolDataQuery *)limitTo:(NSInteger)count;

- (NSPredicate *)buildPredicate;
// Aggiungi questi modelli a SymbolDataModels.h
@end

#pragma mark - WatchlistData per Core Data

@interface WatchlistDataModel : NSManagedObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *watchlistId;
@property (nonatomic, retain) NSDate *dateCreated;
@property (nonatomic, retain) NSDate *lastModified;
@property (nonatomic) BOOL isDynamic;
@property (nonatomic, retain) NSString * _Nullable dynamicTag;
@property (nonatomic, retain) NSSet<SymbolData *> *symbols;
@property (nonatomic) NSInteger sortOrder;

// Helper methods
- (NSArray<NSString *> *)symbolNames;
- (void)addSymbol:(NSString *)symbol;
- (void)removeSymbol:(NSString *)symbol;
- (BOOL)containsSymbol:(NSString *)symbol;



@end

NS_ASSUME_NONNULL_END
