//
//  NoteAnnotationProvider.h
//  mafia_AI
//
//  Provider for personal note annotations
//  Notes are user-created annotations attached to specific dates
//

#import <Foundation/Foundation.h>
#import "ChartAnnotationProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface NoteAnnotationProvider : NSObject <ChartAnnotationProvider>

// TODO: Implementare integrazione con Core Data per personal notes
// Per ora ritorna array vuoto - implementeremo dopo

@end

NS_ASSUME_NONNULL_END
