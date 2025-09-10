//
//  WidgetTypeManager.h
//  TradingApp
//

#import <Foundation/Foundation.h>

@interface WidgetTypeManager : NSObject

+ (instancetype)sharedManager;

// Available widget types
- (NSArray<NSString *> *)availableWidgetTypes;
- (NSArray<NSString *> *)widgetTypesForCategory:(NSString *)category;
- (NSDictionary<NSString *, NSArray<NSString *> *> *)widgetTypesByCategory;

// Widget creation
- (Class)widgetClassForType:(NSString *)type;
- (NSString *)iconNameForWidgetType:(NSString *)type;

// FIX: Aggiunti metodi mancanti utilizzati in BaseWidget.m
- (NSString *)correctNameForType:(NSString *)type;
- (Class)classForWidgetType:(NSString *)type;

@end
