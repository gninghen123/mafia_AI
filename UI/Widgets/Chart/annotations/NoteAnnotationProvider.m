//
//  NoteAnnotationProvider.m
//  mafia_AI
//
//  Placeholder implementation for personal notes
//

#import "NoteAnnotationProvider.h"

@implementation NoteAnnotationProvider

- (ChartAnnotationType)annotationType {
    return ChartAnnotationTypeNote;
}

- (NSString *)providerName {
    return @"Personal Notes";
}

- (BOOL)isEnabled {
    return NO;  // Disabled until Core Data integration is complete
}

- (void)getAnnotationsForSymbol:(NSString *)symbol
                      startDate:(NSDate *)startDate
                        endDate:(NSDate *)endDate
                     completion:(void(^)(NSArray<ChartAnnotation *> *annotations, NSError *error))completion {
    
    // TODO: Implementare caricamento note da Core Data
    // Per ora ritorna array vuoto
    
    NSLog(@"ℹ️ NoteAnnotationProvider: Not yet implemented (placeholder)");
    
    if (completion) {
        completion(@[], nil);
    }
}

@end
