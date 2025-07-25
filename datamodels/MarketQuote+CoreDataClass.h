//
//  MarketQuote+CoreDataClass.h
//  mafia_AI
//
//  Created by fabio gattone on 25/07/25.
//
//

#import <CoreData/CoreData.h>
#import <Cocoa/Cocoa.h>

#pragma mark - MarketQuote Entity
// Memorizza l'ultimo prezzo/quote di un simbolo
@interface MarketQuote : NSManagedObject

@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *exchange;

// Prezzi
@property (nonatomic) double currentPrice;
@property (nonatomic) double previousClose;
@property (nonatomic) double open;
@property (nonatomic) double high;
@property (nonatomic) double low;

// Variazioni
@property (nonatomic) double change;
@property (nonatomic) double changePercent;

// Volume
@property (nonatomic) int64_t volume;
@property (nonatomic) int64_t avgVolume;

// Altri dati
@property (nonatomic) double marketCap;
@property (nonatomic) double pe;
@property (nonatomic) double eps;
@property (nonatomic) double beta;

// Timestamp
@property (nonatomic, strong) NSDate *lastUpdate;
@property (nonatomic, strong) NSDate *marketTime;

// Metodi helper
- (BOOL)isGainer;
- (BOOL)isLoser;
- (NSColor *)changeColor;

@end
