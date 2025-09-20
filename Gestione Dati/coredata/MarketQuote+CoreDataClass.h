//
//  MarketQuote+CoreDataClass.h
//  mafia_AI
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class NSColor;  // Forward declaration

NS_ASSUME_NONNULL_BEGIN

@interface MarketQuote : NSManagedObject

// Metodi helper personalizzati
- (BOOL)isGainer;
- (BOOL)isLoser;
- (NSColor *)changeColor;

@end

NS_ASSUME_NONNULL_END

#import "MarketQuote+CoreDataProperties.h"
