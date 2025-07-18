//
//  AlertManager.m
//  TradingApp
//

#import "AlertManager.h"
#import "DataManager.h"
#import "AppSettings.h"

// Notifiche
NSString *const kAlertTriggeredNotification = @"AlertTriggeredNotification";
NSString *const kAlertsUpdatedNotification = @"AlertsUpdatedNotification";
NSString *const kAlertEntryKey = @"AlertEntry";

@interface AlertManager ()

@property (nonatomic, strong) NSMutableArray<AlertEntry *> *alerts;
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, strong) NSString *alertsFilePath;
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
        _alerts = [NSMutableArray array];
        _alertQueue = dispatch_queue_create("com.tradingapp.alertqueue", DISPATCH_QUEUE_SERIAL);
        
        // Setup file path
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *appSupportDir = [paths firstObject];
        NSString *appDir = [appSupportDir stringByAppendingPathComponent:@"TradingApp"];
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:appDir]) {
            [fm createDirectoryAtPath:appDir withIntermediateDirectories:YES attributes:nil error:nil];
        }
        
        _alertsFilePath = [appDir stringByAppendingPathComponent:@"alerts.json"];
        
        // Carica alerts salvati
        [self loadAlerts];
        
        // Usa le impostazioni per suoni e popup
        AppSettings *settings = [AppSettings sharedSettings];
        _soundEnabled = settings.alertSoundsEnabled;
        _popupEnabled = settings.alertPopupsEnabled;
        
        // Registra per notifiche prezzi dal DataManager
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(priceUpdateReceived:)
                                                     name:@"PriceUpdateNotification"
                                                   object:nil];
        
        // Registra per cambiamenti delle impostazioni
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:@"AppSettingsDidChange"
                                                   object:nil];
        
        // Timer usando le impostazioni
        [self setupTimerWithInterval:settings.alertBackupInterval];
    }
    return self;
}

- (void)setupTimerWithInterval:(NSTimeInterval)interval {
    if (_checkTimer) {
        [_checkTimer invalidate];
    }
    
    _checkTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                   target:self
                                                 selector:@selector(checkAllAlerts)
                                                 userInfo:nil
                                                  repeats:YES];
}

- (void)settingsDidChange:(NSNotification *)notification {
    AppSettings *settings = [AppSettings sharedSettings];
    
    // Aggiorna le impostazioni
    self.soundEnabled = settings.alertSoundsEnabled;
    self.popupEnabled = settings.alertPopupsEnabled;
    
    // Aggiorna il timer se l'intervallo è cambiato
    [self setupTimerWithInterval:settings.alertBackupInterval];
}

- (void)dealloc {
    [_checkTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Gestione Alert

- (void)addAlert:(AlertEntry *)alert {
    NSLog(@"=== AlertManager addAlert INIZIATO ===");
    NSLog(@"Alert ricevuto: %@", alert);
    NSLog(@"  ID: %@", alert.alertID);
    NSLog(@"  Symbol: %@", alert.symbol);
    NSLog(@"  Price: %.5f", alert.targetPrice);
    NSLog(@"  Status: %ld", (long)alert.status);
    
    if (!alert) {
        NSLog(@"ERRORE: Alert è nil!");
        return;
    }
    
    if (!alert.symbol) {
        NSLog(@"ERRORE: Symbol è nil!");
        return;
    }
    
    if (alert.targetPrice <= 0) {
        NSLog(@"ERRORE: TargetPrice non valido: %.5f", alert.targetPrice);
        return;
    }
    
    NSLog(@"Alert valido, aggiungendo alla coda...");
    
    dispatch_async(self.alertQueue, ^{
        NSLog(@"Dentro la alertQueue - aggiungendo alert...");
        [self.alerts addObject:alert];
        NSLog(@"Alert aggiunto. Totale alert ora: %ld", (long)self.alerts.count);
        
        [self saveAlerts];
        NSLog(@"Alert salvati su disco");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"Notificando aggiornamento alert su main queue...");
            [self notifyAlertsUpdated];
            NSLog(@"=== AlertManager addAlert COMPLETATO ===");
        });
    });
}

- (void)removeAlert:(AlertEntry *)alert {
    [self removeAlertWithID:alert.alertID];
}

- (void)removeAlertWithID:(NSString *)alertID {
    if (!alertID) return;
    
    dispatch_async(self.alertQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"alertID != %@", alertID];
        [self.alerts filterUsingPredicate:predicate];
        [self saveAlerts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self notifyAlertsUpdated];
        });
    });
}

- (void)updateAlert:(AlertEntry *)alert {
    if (!alert || !alert.alertID) return;
    
    dispatch_async(self.alertQueue, ^{
        NSUInteger index = [self.alerts indexOfObjectPassingTest:^BOOL(AlertEntry *obj, NSUInteger idx, BOOL *stop) {
            return [obj.alertID isEqualToString:alert.alertID];
        }];
        
        if (index != NSNotFound) {
            self.alerts[index] = [alert copy];
            [self saveAlerts];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self notifyAlertsUpdated];
            });
        }
    });
}

- (AlertEntry *)alertWithID:(NSString *)alertID {
    if (!alertID) return nil;
    
    __block AlertEntry *result = nil;
    dispatch_sync(self.alertQueue, ^{
        NSUInteger index = [self.alerts indexOfObjectPassingTest:^BOOL(AlertEntry *obj, NSUInteger idx, BOOL *stop) {
            return [obj.alertID isEqualToString:alertID];
        }];
        
        if (index != NSNotFound) {
            result = [self.alerts[index] copy];
        }
    });
    
    return result;
}

- (NSArray<AlertEntry *> *)alertsForSymbol:(NSString *)symbol {
    if (!symbol) return @[];
    
    __block NSArray *result = nil;
    dispatch_sync(self.alertQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        result = [[self.alerts filteredArrayUsingPredicate:predicate] copy];
    });
    
    return result;
}

#pragma mark - Attivazione/Disattivazione

- (void)enableAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    alert.status = AlertStatusActive;
    [self updateAlert:alert];
}

- (void)disableAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    alert.status = AlertStatusDisabled;
    [self updateAlert:alert];
}

- (void)resetTriggeredAlert:(AlertEntry *)alert {
    if (!alert) return;
    
    alert.status = AlertStatusActive;
    alert.triggerDate = nil;
    [self updateAlert:alert];
}

#pragma mark - Properties

- (NSArray<AlertEntry *> *)allAlerts {
    __block NSArray *result = nil;
    dispatch_sync(self.alertQueue, ^{
        result = [self.alerts copy];
    });
    return result;
}

- (NSArray<AlertEntry *> *)activeAlerts {
    __block NSArray *result = nil;
    dispatch_sync(self.alertQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %d", AlertStatusActive];
        result = [[self.alerts filteredArrayUsingPredicate:predicate] copy];
    });
    return result;
}

- (NSArray<AlertEntry *> *)triggeredAlerts {
    __block NSArray *result = nil;
    dispatch_sync(self.alertQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %d", AlertStatusTriggered];
        result = [[self.alerts filteredArrayUsingPredicate:predicate] copy];
    });
    return result;
}

#pragma mark - Check Prezzi

- (void)priceUpdateReceived:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    NSString *symbol = userInfo[@"symbol"];
    NSNumber *priceNumber = userInfo[@"price"];
    
    if (symbol && priceNumber) {
        [self checkAlertsForSymbol:symbol price:[priceNumber doubleValue]];
    }
}

- (void)checkAlertsForSymbol:(NSString *)symbol price:(double)price {
    if (!symbol || price <= 0) return;
    
    dispatch_async(self.alertQueue, ^{
        // NON usare [self alertsForSymbol:symbol] qui dentro perché causerebbe deadlock
        // Invece filtra direttamente l'array self.alerts
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
        NSArray *symbolAlerts = [self.alerts filteredArrayUsingPredicate:predicate];
        
        for (AlertEntry *alert in symbolAlerts) {
            if (alert.status == AlertStatusActive && [alert shouldTriggerForPrice:price]) {
                alert.status = AlertStatusTriggered;
                alert.triggerDate = [NSDate date];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self handleTriggeredAlert:alert];
                });
            }
        }
        
        [self saveAlerts];
    });
}

- (void)checkAllAlerts {
    // Ottieni tutti i prezzi correnti dal DataManager
    DataManager *dataManager = [DataManager sharedManager];
    
    dispatch_async(self.alertQueue, ^{
        // NON usare self.activeAlerts qui dentro perché causerebbe deadlock
        // Invece filtra direttamente l'array self.alerts
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status == %d", AlertStatusActive];
        NSArray *activeAlerts = [self.alerts filteredArrayUsingPredicate:predicate];
        
        for (AlertEntry *alert in activeAlerts) {
            NSDictionary *symbolData = [dataManager dataForSymbol:alert.symbol];
            if (symbolData) {
                double currentPrice = [symbolData[@"last"] doubleValue];
                if (currentPrice > 0 && [alert shouldTriggerForPrice:currentPrice]) {
                    alert.status = AlertStatusTriggered;
                    alert.triggerDate = [NSDate date];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self handleTriggeredAlert:alert];
                    });
                }
            }
        }
        
        [self saveAlerts];
    });
}

#pragma mark - Gestione Alert Scattati

- (void)handleTriggeredAlert:(AlertEntry *)alert {
    // Notifica delegate
    if ([self.delegate respondsToSelector:@selector(alertManager:didTriggerAlert:)]) {
        [self.delegate alertManager:self didTriggerAlert:alert];
    }
    
    // Post notification
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlertTriggeredNotification
                                                        object:self
                                                      userInfo:@{kAlertEntryKey: alert}];
    
    // Suono usando le impostazioni
    if (self.soundEnabled) {
        AppSettings *settings = [AppSettings sharedSettings];
        NSSound *alertSound = [NSSound soundNamed:settings.alertSoundName];
        [alertSound play];
    }
    
    // Popup
    if (self.popupEnabled) {
        [self showAlertPopup:alert];
    }
    
    [self notifyAlertsUpdated];
}

- (void)showAlertPopup:(AlertEntry *)alert {
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"Alert Prezzo Scattato!";
    notification.informativeText = [NSString stringWithFormat:@"%@ ha raggiunto %.2f (%@)",
                                   alert.symbol,
                                   alert.targetPrice,
                                   alert.alertTypeString];
    
    // Usa il suono dalle impostazioni
    AppSettings *settings = [AppSettings sharedSettings];
    notification.soundName = settings.alertSoundName;
    
    notification.hasActionButton = YES;
    notification.actionButtonTitle = @"Visualizza";
    notification.userInfo = @{@"alertID": alert.alertID};
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

#pragma mark - Salvataggio/Caricamento

- (void)saveAlerts {
    NSMutableArray *alertsData = [NSMutableArray array];
    for (AlertEntry *alert in self.alerts) {
        [alertsData addObject:[alert toDictionary]];
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:alertsData
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (!error) {
        [jsonData writeToFile:self.alertsFilePath atomically:YES];
    } else {
        NSLog(@"Errore nel salvataggio alerts: %@", error);
    }
}

- (void)loadAlerts {
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.alertsFilePath]) {
        NSData *jsonData = [NSData dataWithContentsOfFile:self.alertsFilePath];
        NSError *error;
        NSArray *alertsData = [NSJSONSerialization JSONObjectWithData:jsonData
                                                              options:0
                                                                error:&error];
        
        if (!error && [alertsData isKindOfClass:[NSArray class]]) {
            [self.alerts removeAllObjects];
            for (NSDictionary *alertDict in alertsData) {
                AlertEntry *alert = [AlertEntry fromDictionary:alertDict];
                if (alert) {
                    [self.alerts addObject:alert];
                }
            }
        }
    }
}

#pragma mark - Pulizia

- (void)removeAllAlerts {
    dispatch_async(self.alertQueue, ^{
        [self.alerts removeAllObjects];
        [self saveAlerts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self notifyAlertsUpdated];
        });
    });
}

- (void)removeTriggeredAlerts {
    dispatch_async(self.alertQueue, ^{
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"status != %d", AlertStatusTriggered];
        [self.alerts filterUsingPredicate:predicate];
        [self saveAlerts];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self notifyAlertsUpdated];
        });
    });
}

#pragma mark - Helper

- (void)notifyAlertsUpdated {
    if ([self.delegate respondsToSelector:@selector(alertManagerDidUpdateAlerts:)]) {
        [self.delegate alertManagerDidUpdateAlerts:self];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kAlertsUpdatedNotification
                                                        object:self];
}

@end
