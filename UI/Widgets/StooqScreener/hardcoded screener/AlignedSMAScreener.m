// ============================================================================
//  AlignedSMAScreener.m
//  TradingApp
// ============================================================================

#import "AlignedSMAScreener.h"
#import "TechnicalIndicatorHelper.h"

@implementation AlignedSMAScreener

#pragma mark - BaseScreener Overrides

- (NSString *)screenerID {
    return @"aligned_sma";
}

- (NSString *)displayName {
    return @"Aligned SMA";
}

- (NSString *)descriptionText {
    return @"Filters symbols with aligned moving averages (e.g., SMA10 > SMA20 > SMA50). Optional close price above first SMA.";
}

- (NSInteger)minBarsRequired {
    // Il massimo periodo tra le SMA configurate
    NSInteger sma1 = [self parameterIntegerForKey:@"sma1" defaultValue:10];
    NSInteger sma2 = [self parameterIntegerForKey:@"sma2" defaultValue:20];
    NSInteger sma3 = [self parameterIntegerForKey:@"sma3" defaultValue:50];
    NSInteger numSMAs = [self parameterIntegerForKey:@"numSMAs" defaultValue:3];
    
    NSInteger maxPeriod = sma1;
    if (numSMAs >= 2) maxPeriod = MAX(maxPeriod, sma2);
    if (numSMAs >= 3) maxPeriod = MAX(maxPeriod, sma3);
    
    return maxPeriod + 1; // +1 per sicurezza
}

- (NSDictionary *)defaultParameters {
    return @{
        @"numSMAs": @3,           // Numero di medie da usare (2 o 3)
        @"sma1": @5,             // Periodo SMA più veloce
        @"sma2": @10,             // Periodo SMA media
        @"sma3": @20,             // Periodo SMA più lenta
        @"requireCloseAbove": @NO // Close deve essere > SMA1?
    };
}

#pragma mark - Execution


- (NSArray<NSString *> *)executeOnSymbols:(NSArray<NSString *> *)inputSymbols
                               cachedData:(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *)cache {
    
    // Leggi parametri
    NSInteger numSMAs = [self parameterIntegerForKey:@"numSMAs" defaultValue:3];
    NSInteger sma1Period = [self parameterIntegerForKey:@"sma1" defaultValue:5];
    NSInteger sma2Period = [self parameterIntegerForKey:@"sma2" defaultValue:10];
    NSInteger sma3Period = [self parameterIntegerForKey:@"sma3" defaultValue:20];
    BOOL requireCloseAbove = [self parameterBoolForKey:@"requireCloseAbove" defaultValue:NO];
    
    // Validazione
    if (numSMAs < 2 || numSMAs > 3) {
        NSLog(@"⚠️ AlignedSMAScreener: numSMAs deve essere 2 o 3, ricevuto %ld", (long)numSMAs);
        return @[];
    }
    
    if (sma1Period >= sma2Period || (numSMAs == 3 && sma2Period >= sma3Period)) {
        NSLog(@"⚠️ AlignedSMAScreener: I periodi devono essere in ordine crescente (sma1 < sma2 < sma3)");
        return @[];
    }
    
    NSMutableArray<NSString *> *results = [NSMutableArray array];
    
    for (NSString *symbol in inputSymbols) {
        NSArray<HistoricalBarModel *> *bars = [self barsForSymbol:symbol inCache:cache];
        
        if (!bars || bars.count < self.minBarsRequired) {
            continue;
        }
        
        // Calcola le SMA sulla barra più recente (index = 0)
        // NOTA: TechnicalIndicatorHelper usa index=0 per l'ultima barra (più recente)
        double sma1 = [TechnicalIndicatorHelper sma:bars index:0 period:sma1Period valueKey:@"close"];
        double sma2 = [TechnicalIndicatorHelper sma:bars index:0 period:sma2Period valueKey:@"close"];
        double sma3 = 0.0;
        
        if (numSMAs == 3) {
            sma3 = [TechnicalIndicatorHelper sma:bars index:0 period:sma3Period valueKey:@"close"];
        }
        
        // Verifica che i valori siano validi
        if (sma1 == 0.0 || sma2 == 0.0) {
            continue;
        }
        
        if (numSMAs == 3 && sma3 == 0.0) {
            continue;
        }
        
        // Prendi il close più recente
        HistoricalBarModel *currentBar = bars.lastObject;
        double currentClose = currentBar.close;
        
        // Verifica allineamento
        BOOL aligned = NO;
        
        if (numSMAs == 2) {
            // Solo 2 medie: SMA1 > SMA2
            aligned = (sma1 > sma2);
        } else {
            // 3 medie: SMA1 > SMA2 > SMA3
            aligned = (sma1 > sma2) && (sma2 > sma3);
        }
        
        // Verifica condizione Close (se richiesta)
        if (aligned && requireCloseAbove) {
            aligned = (currentClose > sma1);
        }
        
        // Aggiungi ai risultati se passa il filtro
        if (aligned) {
            [results addObject:symbol];
            
            if (numSMAs == 2) {
                NSLog(@"✓ %@: SMA%ld(%.2f) > SMA%ld(%.2f)%@",
                      symbol,
                      (long)sma1Period, sma1,
                      (long)sma2Period, sma2,
                      requireCloseAbove ? [NSString stringWithFormat:@", Close(%.2f) > SMA%ld", currentClose, (long)sma1Period] : @"");
            } else {
                NSLog(@"✓ %@: SMA%ld(%.2f) > SMA%ld(%.2f) > SMA%ld(%.2f)%@",
                      symbol,
                      (long)sma1Period, sma1,
                      (long)sma2Period, sma2,
                      (long)sma3Period, sma3,
                      requireCloseAbove ? [NSString stringWithFormat:@", Close(%.2f) > SMA%ld", currentClose, (long)sma1Period] : @"");
            }
        }
    }
    
    NSLog(@"📊 AlignedSMAScreener: %lu/%lu symbols passed", (unsigned long)results.count, (unsigned long)inputSymbols.count);
    
    return [results copy];
}

@end
