//
//  Watchlist+Extensions.h
//  mafia_AI
//

#import "Watchlist+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface Watchlist (Extensions)

// Proprietà temporanea finché non viene aggiunta al Core Data model
@property (nonatomic, assign) BOOL isFavorite;

@end

NS_ASSUME_NONNULL_END
