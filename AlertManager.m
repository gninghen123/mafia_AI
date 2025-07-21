//
//  AlertManager.m
//  TradingApp
//
//  VERSIONE PULITA - Usa solo SymbolDataHub
//

#import "AlertManager.h"
#import "SymbolDataHub.h"
#import "SymbolDataModels.h"
#import "AlertEntry.h"

// Notifiche
NSString *const kAlertTriggeredNotification = @"AlertTriggeredNotification";
NSString *const kAlertsUpdatedNotification = @"AlertsUpdatedNotification";
NSString *const kAlertEntryKey = @"AlertEntry";

@interface AlertManager ()
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, strong) dispatch_queue_t alertQueue;
@end

@implementation AlertManager

+ (instancetype)sharedManager {
    static AlertManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    return sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _alertQueue = dispatch_queue_create("com.tradingapp.alertqueue", DISPATCH_QUEUE_SERIAL);
        
        // Osserva notifiche dal DataHub
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dataHubAlertTriggered:)
                                                     name:kAlertTriggeredNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dataHubUpdated:)
                                                     name:kSymbolDataUpdatedNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [self stopMonitoring];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)startMonitoring {
    [self stopMonitoring];
    
    // Check ogni 5 secondi
    self.checkTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                        target:self
                                                      selector:@selector(checkAlerts)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)stopMonitoring {
    [self.checkTimer invalidate];
    self.checkTimer = nil;
}

- (NSArray<AlertEntry *> *)allAlerts {
    // Ottieni dal DataHub e converti
    NSArray<AlertData *> *dataHubAlerts = [[SymbolDataHub sharedHub] allActiveAlerts];
    NSMutableArray<AlertEntry *> *entries = [NSMutableArray array];
    
    for (AlertData *alert in dataHubAlerts) {
        AlertEntry *entry = [AlertEntry fromAlertData:alert];
        if (entry) {
            [entries addObject:entry];
        }
    }
    
    return entries;
}

- (NSArray<AlertEntry *> *)alertsForSymbol:(NSString *)symbol {
    NSArray<AlertData *> *dataHubAlerts = [[SymbolDataHub sharedHub] alertsForSymbol:symbol];
    NSMutableArray<AlertEntry *> *entries = [NSMutableArray array];
    
    for (AlertData *alert in dataHubAlerts) {
        AlertEntry *entry = [AlertEntry fromAlertData:alert];
        if (entry) {
            [entries addObject:entry];
        }
    }
    
    return entries;
}

- (void)addAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    NSDictionary *conditions = @{
        @"price": @(alert.targetPrice),
        @"comparison": alert.alertType == AlertTypePriceAbove ? @"above" : @"below"
    };
    
    AlertData *dataHubAlert = [[SymbolDataHub sharedHub] addAlertForSymbol:alert.symbol
                                                                       type:alert.alertType == AlertTypePriceAbove ? @"priceAbove" : @"priceBelow"
                                                                  condition:conditions];
    
    if (alert.notes) {
        dataHubAlert.message = alert.notes;
    }
    
    [[SymbolDataHub sharedHub] saveContext];
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlertsUpdatedNotification object:self];
    
    if ([self.delegate respondsToSelector:@selector(alertManagerDidUpdateAlerts:)]) {
        [self.delegate alertManagerDidUpdateAlerts:self];
    }
}

- (void)removeAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] alertsForSymbol:alert.symbol];
    
    for (AlertData *dataHubAlert in alerts) {
        if ([dataHubAlert.alertId isEqualToString:alert.alertID]) {
            [[SymbolDataHub sharedHub] removeAlert:dataHubAlert];
            break;
        }
    }
    
    // Notifica
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlertsUpdatedNotification object:self];
    
    if ([self.delegate respondsToSelector:@selector(alertManagerDidUpdateAlerts:)]) {
        [self.delegate alertManagerDidUpdateAlerts:self];
    }
}

- (void)updateAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    NSArray<AlertData *> *alerts = [[SymbolDataHub sharedHub] alertsForSymbol:alert.symbol];
    
    for (AlertData *dataHubAlert in alerts) {
        if ([dataHubAlert.alertId isEqualToString:alert.alertID]) {
            // Aggiorna status
            dataHubAlert.status = alert.status;
            if (alert.notes) {
                dataHubAlert.message = alert.notes;
            }
            [[SymbolDataHub sharedHub] saveContext];
            break;
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlertsUpdatedNotification object:self];
}

- (void)clearTriggeredAlerts {
    NSArray<AlertData *> *allAlerts = [[SymbolDataHub sharedHub] allActiveAlerts];
    
    for (AlertData *alert in allAlerts) {
        if (alert.status == AlertStatusTriggered) {
            [[SymbolDataHub sharedHub] removeAlert:alert];
        }
    }
}

#pragma mark - Private Methods

- (void)checkAlerts {
    dispatch_async(self.alertQueue, ^{
        NSArray<AlertData *> *activeAlerts = [[SymbolDataHub sharedHub] allActiveAlerts];
        
        for (AlertData *alert in activeAlerts) {
            if (![alert shouldCheckCondition]) continue;
            
            NSString *symbol = alert.symbol.symbol;
            double currentPrice = [self getCurrentPriceForSymbol:symbol];
            
            if (currentPrice > 0) {
                [self checkAlert:alert withPrice:currentPrice];
            }
        }
    });
}

- (void)checkAlert:(AlertData *)alert withPrice:(double)currentPrice {
    NSNumber *targetPrice = alert.conditions[@"price"];
    if (!targetPrice) return;
    
    BOOL shouldTrigger = NO;
    
    if (alert.type == AlertTypePriceAbove && currentPrice >= targetPrice.doubleValue) {
        shouldTrigger = YES;
    } else if (alert.type == AlertTypePriceBelow && currentPrice <= targetPrice.doubleValue) {
        shouldTrigger = YES;
    }
    
    if (shouldTrigger && alert.status == AlertStatusActive) {
        // Triggera l'alert
        [[SymbolDataHub sharedHub] updateAlertStatus:alert triggered:YES];
        
        // Converti per delegate
        AlertEntry *entry = [AlertEntry fromAlertData:alert];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self.delegate respondsToSelector:@selector(alertManager:didTriggerAlert:)]) {
                [self.delegate alertManager:self didTriggerAlert:entry];
            }
        });
    }
}

- (double)getCurrentPriceForSymbol:(NSString *)symbol {
    // TODO: Implementa ottenimento prezzo real-time
    // Per ora ritorna un valore dummy
    return 0;
}

#pragma mark - DataHub Notifications

- (void)dataHubAlertTriggered:(NSNotification *)notification {
    AlertData *alert = notification.userInfo[@"alert"];
    AlertEntry *entry = [AlertEntry fromAlertData:alert];
    
    if ([self.delegate respondsToSelector:@selector(alertManager:didTriggerAlert:)]) {
        [self.delegate alertManager:self didTriggerAlert:entry];
    }
}

- (void)dataHubUpdated:(NSNotification *)notification {
    SymbolUpdateType updateType = [notification.userInfo[kUpdateTypeKey] integerValue];
    
    if (updateType == SymbolUpdateTypeAlerts || updateType == SymbolUpdateTypeAll) {
        if ([self.delegate respondsToSelector:@selector(alertManagerDidUpdateAlerts:)]) {
            [self.delegate alertManagerDidUpdateAlerts:self];
        }
    }
}

@end
