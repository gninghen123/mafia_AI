//
//  AlertManager.h
//  TradingApp
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "AlertEntry.h"

// Notifiche
extern NSString *const kAlertTriggeredNotification;
extern NSString *const kAlertsUpdatedNotification;
extern NSString *const kAlertEntryKey;

@class DataManager;

@protocol AlertManagerDelegate <NSObject>
@optional
- (void)alertManager:(id)manager didTriggerAlert:(AlertEntry *)alert;
- (void)alertManagerDidUpdateAlerts:(id)manager;
@end

@interface AlertManager : NSObject

@property (nonatomic, weak) id<AlertManagerDelegate> delegate;
@property (nonatomic, readonly) NSArray<AlertEntry *> *allAlerts;
@property (nonatomic, readonly) NSArray<AlertEntry *> *activeAlerts;
@property (nonatomic, readonly) NSArray<AlertEntry *> *triggeredAlerts;
@property (nonatomic, assign) BOOL soundEnabled;
@property (nonatomic, assign) BOOL popupEnabled;

// Singleton
+ (instancetype)sharedManager;

// Gestione Alert
- (void)addAlert:(AlertEntry *)alert;
- (void)removeAlert:(AlertEntry *)alert;
- (void)removeAlertWithID:(NSString *)alertID;
- (void)updateAlert:(AlertEntry *)alert;
- (AlertEntry *)alertWithID:(NSString *)alertID;
- (NSArray<AlertEntry *> *)alertsForSymbol:(NSString *)symbol;

// Attivazione/Disattivazione
- (void)enableAlert:(AlertEntry *)alert;
- (void)disableAlert:(AlertEntry *)alert;
- (void)resetTriggeredAlert:(AlertEntry *)alert;

// Salvataggio/Caricamento
- (void)saveAlerts;
- (void)loadAlerts;

// Check prezzi (chiamato dal DataManager)
- (void)checkAlertsForSymbol:(NSString *)symbol price:(double)price;
- (void)checkAllAlerts;

// Pulizia
- (void)removeAllAlerts;
- (void)removeTriggeredAlerts;

@end
