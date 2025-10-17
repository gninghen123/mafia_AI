
// ============================================================================
// StooqScreenerWidget+ImageReport.m
// ============================================================================

#import "StooqScreenerWidget+ImageReport.h"
#import "StooqScreenerWidget+Private.h"
#import "MiniChart.h"
#import "ExecutionSession.h"
#import "ScreenerModel.h"  // ✅ CORRETTO: ModelResult è definito qui
#import "ScreenedSymbol.h"
#import "runtimemodels.h"
#import "StooqDataManager.h"


@implementation StooqScreenerWidget (ImageReport)

#pragma mark - Public API

- (void)generateImageReportWithSelectedOnly:(BOOL)selectedOnly {
    NSLog(@"🖼️ Generating image report (%@)...", selectedOnly ? @"selected" : @"all");
    
    // Raccogli modelli e simboli
    NSArray<ModelResult *> *modelsToProcess = [self modelsToProcess];
    if (modelsToProcess.count == 0) {
        NSLog(@"⚠️ No models to process");
        [self showAlert:@"No Data" message:@"No models available for report generation"];
        return;
    }
    
    // Prepara i dati per il report
    NSMutableArray *reportData = [NSMutableArray array];
    NSMutableSet *allSymbols = [NSMutableSet set];
    
    for (ModelResult *result in modelsToProcess) {
        NSMutableArray<NSString *> *symbolsToInclude = [NSMutableArray array];
        
        for (ScreenedSymbol *symbol in result.screenedSymbols) {
            if (!selectedOnly || symbol.isSelected) {
                [symbolsToInclude addObject:symbol.symbol];
                [allSymbols addObject:symbol.symbol];
            }
        }
        
        if (symbolsToInclude.count > 0) {
            [reportData addObject:@{
                @"modelName": result.modelName,
                @"symbols": symbolsToInclude
            }];
        }
    }
    
    if (reportData.count == 0) {
        NSLog(@"⚠️ No symbols to include in report");
        [self showAlert:@"No Symbols" message:@"No symbols available for report generation"];
        return;
    }
    
    // ✅ VERIFICA CACHE - se non abbiamo tutti i dati, caricali
    BOOL needsDataLoad = NO;
    
    if (!self.lastScreeningCache) {
        needsDataLoad = YES;
        NSLog(@"⚠️ No cache available, need to load data");
    } else {
        // Verifica che la cache contenga tutti i simboli necessari
        NSInteger missingCount = 0;
        for (NSString *symbol in allSymbols) {
            if (!self.lastScreeningCache[symbol]) {
                missingCount++;
            }
        }
        
        if (missingCount > 0) {
            needsDataLoad = YES;
            NSLog(@"⚠️ Cache missing %ld symbols, need to load data", (long)missingCount);
        }
    }
    
    if (needsDataLoad) {
        NSLog(@"📊 Loading historical data for %lu symbols...", (unsigned long)allSymbols.count);
        
        // ✅ USA IL METODO ESISTENTE per caricare i dati
        [self loadHistoricalDataForReportGeneration:[allSymbols allObjects]
                                         completion:^(BOOL success) {
            if (success) {
                [self createImageReportWithData:reportData selectedOnly:selectedOnly];
            } else {
                [self showAlert:@"Data Load Failed"
                        message:@"Could not load historical data for report generation"];
            }
        }];
    } else {
        NSLog(@"✅ All data in cache, generating report immediately");
        [self createImageReportWithData:reportData selectedOnly:selectedOnly];
    }
}


#pragma mark - Data Loading Helper

- (void)loadHistoricalDataForReportGeneration:(NSArray<NSString *> *)symbols
                                    completion:(void (^)(BOOL success))completion {
    
    if (!self.dataManager) {
        NSLog(@"❌ No data manager available");
        if (completion) completion(NO);
        return;
    }
    
    // Usa la data della session selezionata
    NSDate *targetDate = self.selectedSession.executionDate;
    if (!targetDate) {
        targetDate = [self.dataManager expectedLastCloseDate];
    }
    
    // Calcola minBars necessari
    NSInteger minBars = 100;
    if (self.selectedModelResult) {
        minBars = [self calculateMinBarsForModelResult:self.selectedModelResult];
    } else if (self.selectedSession) {
        minBars = [self calculateMinBarsForSession:self.selectedSession];
    }
    
    // Imposta target date
    self.dataManager.targetDate = targetDate;
    
    NSLog(@"📊 Loading %ld bars for %lu symbols for report generation...",
          (long)minBars, (unsigned long)symbols.count);
    
    // Carica i dati
    [self.dataManager loadDataForSymbols:symbols
                                 minBars:minBars
                              completion:^(NSDictionary<NSString *, NSArray<HistoricalBarModel *> *> *cache, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !cache || cache.count == 0) {
                NSLog(@"❌ Failed to load data for report: %@", error ?: @"No data");
                if (completion) completion(NO);
                return;
            }
            
            NSLog(@"✅ Loaded %lu symbols for report", (unsigned long)cache.count);
            
            // Salva nella cache
            if (self.selectedSession) {
                if (self.lastScreeningCache && self.cachedSessionID &&
                    [self.cachedSessionID isEqualToString:self.selectedSession.sessionID]) {
                    NSMutableDictionary *merged = [self.lastScreeningCache mutableCopy];
                    [merged addEntriesFromDictionary:cache];
                    self.lastScreeningCache = [merged copy];
                } else {
                    self.lastScreeningCache = cache;
                    self.lastScreeningDate = targetDate;
                    self.cachedSessionID = self.selectedSession.sessionID;
                }
            } else {
                self.lastScreeningCache = cache;
                self.lastScreeningDate = targetDate;
                self.cachedSessionID = nil;
            }
            
            if (completion) completion(YES);
        });
    }];
}

#pragma mark - Helper Methods

- (NSArray<ModelResult *> *)modelsToProcess {
    if (self.selectedModelResult) {
        return @[self.selectedModelResult];
    } else if (self.selectedSession) {
        return self.selectedSession.modelResults;
    }
    return @[];
}

- (void)createImageReportWithData:(NSArray<NSDictionary *> *)reportData
                     selectedOnly:(BOOL)selectedOnly {
    
    // Layout configuration
    NSInteger chartsPerRow = 4;
    CGFloat chartWidth = 200;
    CGFloat chartHeight = 150;
    CGFloat padding = 10;
    CGFloat headerHeight = 60;
    CGFloat modelHeaderHeight = 40;
    CGFloat footerHeight = 30;
    
    // Calculate total dimensions
    NSInteger maxSymbolsInModel = 0;
    for (NSDictionary *modelData in reportData) {
        NSArray *symbols = modelData[@"symbols"];
        maxSymbolsInModel = MAX(maxSymbolsInModel, symbols.count);
    }
    
    CGFloat imageWidth = (chartWidth * chartsPerRow) + (padding * (chartsPerRow + 1));
    
    // Calculate height per model
    CGFloat heightPerModel = 0;
    for (NSDictionary *modelData in reportData) {
        NSArray *symbols = modelData[@"symbols"];
        NSInteger rows = (symbols.count + chartsPerRow - 1) / chartsPerRow;
        heightPerModel += modelHeaderHeight + (rows * (chartHeight + padding)) + padding;
    }
    
    CGFloat imageHeight = headerHeight + heightPerModel + footerHeight;
    
    NSLog(@"📐 Image dimensions: %.0fx%.0f", imageWidth, imageHeight);
    
    // Create image
    NSImage *reportImage = [[NSImage alloc] initWithSize:NSMakeSize(imageWidth, imageHeight)];
    [reportImage lockFocus];
    
    // ✅ DARK MODE: Background scuro come i MiniChart
    [[NSColor colorWithWhite:0.15 alpha:1.0] setFill];  // Grigio molto scuro
    NSRectFill(NSMakeRect(0, 0, imageWidth, imageHeight));
    
    // Draw header
    CGFloat currentY = imageHeight - headerHeight;
    [self drawReportHeader:NSMakeRect(0, currentY, imageWidth, headerHeight)];
    
    currentY -= padding;
    
    // Process each model
    for (NSDictionary *modelData in reportData) {
        NSString *modelName = modelData[@"modelName"];
        NSArray<NSString *> *symbols = modelData[@"symbols"];
        
        // Draw model header
        currentY -= modelHeaderHeight;
        [self drawModelHeader:modelName
                      symbols:symbols
                       inRect:NSMakeRect(padding, currentY, imageWidth - 2*padding, modelHeaderHeight)];
        
        currentY -= padding;
        
        // Draw charts
        currentY = [self drawChartsForSymbols:symbols
                                      startingY:currentY
                                     imageWidth:imageWidth
                                     chartWidth:chartWidth
                                    chartHeight:chartHeight
                                        padding:padding
                                  chartsPerRow:chartsPerRow];
        
        currentY -= padding;
    }
    
    // Draw footer
    [self drawReportFooter:NSMakeRect(0, 0, imageWidth, footerHeight)];
    
    [reportImage unlockFocus];
    
    // Save image
    [self saveReportImage:reportImage selectedOnly:selectedOnly];
}

- (void)drawReportHeader:(NSRect)rect {
    // ✅ DARK MODE: Background nero/grigio molto scuro
    [[NSColor colorWithWhite:0.12 alpha:1.0] setFill];
    NSRectFill(rect);
    
    // ✅ Bordo in basso (grigio medio per contrasto)
    [[NSColor colorWithWhite:0.3 alpha:1.0] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y)
                              toPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y)];
    
    // Date string
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    
    NSDate *reportDate = self.selectedSession ? self.selectedSession.executionDate : [NSDate date];
    NSString *dateString = [formatter stringFromDate:reportDate];
    
    // Title
    NSString *title = @"SCREENER REPORT";
    NSString *subtitle = dateString;
    
    // Title attributes
    NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
    centerStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *titleAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:18],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.95 alpha:1.0],  // ✅ Bianco quasi puro
        NSParagraphStyleAttributeName: centerStyle
    };
    
    NSDictionary *subtitleAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.7 alpha:1.0],  // ✅ Grigio chiaro
        NSParagraphStyleAttributeName: centerStyle
    };
    
    // Draw title
    NSRect titleRect = NSMakeRect(rect.origin.x, rect.origin.y + 25, rect.size.width, 20);
    [title drawInRect:titleRect withAttributes:titleAttrs];
    
    // Draw subtitle
    NSRect subtitleRect = NSMakeRect(rect.origin.x, rect.origin.y + 8, rect.size.width, 15);
    [subtitle drawInRect:subtitleRect withAttributes:subtitleAttrs];
}


- (void)drawModelHeader:(NSString *)modelName
                symbols:(NSArray<NSString *> *)symbols
                 inRect:(NSRect)rect {
    
    // ✅ DARK MODE: Background grigio scuro
    [[NSColor colorWithWhite:0.18 alpha:1.0] setFill];
    NSRectFill(rect);
    
    // ✅ Bordo superiore e inferiore (grigio medio)
    [[NSColor colorWithWhite:0.35 alpha:1.0] setStroke];
    NSBezierPath *borderPath = [NSBezierPath bezierPath];
    [borderPath moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y + rect.size.height)];
    [borderPath lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y + rect.size.height)];
    [borderPath moveToPoint:NSMakePoint(rect.origin.x, rect.origin.y)];
    [borderPath lineToPoint:NSMakePoint(rect.origin.x + rect.size.width, rect.origin.y)];
    [borderPath stroke];
    
    // Model name
    NSMutableParagraphStyle *leftStyle = [[NSMutableParagraphStyle alloc] init];
    leftStyle.alignment = NSTextAlignmentLeft;
    
    NSDictionary *nameAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:14],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.95 alpha:1.0],  // ✅ Bianco chiaro
        NSParagraphStyleAttributeName: leftStyle
    };
    
    NSRect nameRect = NSMakeRect(rect.origin.x + 10, rect.origin.y + 20, rect.size.width - 20, 16);
    [modelName drawInRect:nameRect withAttributes:nameAttrs];
    
    // Symbols CSV
    NSString *symbolsCSV = [symbols componentsJoinedByString:@", "];
    
    NSDictionary *symbolsAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.65 alpha:1.0],  // ✅ Grigio chiaro
        NSParagraphStyleAttributeName: leftStyle
    };
    
    NSRect symbolsRect = NSMakeRect(rect.origin.x + 10, rect.origin.y + 5, rect.size.width - 20, 14);
    [symbolsCSV drawInRect:symbolsRect withAttributes:symbolsAttrs];
}

- (CGFloat)drawChartsForSymbols:(NSArray<NSString *> *)symbols
                       startingY:(CGFloat)startY
                      imageWidth:(CGFloat)imageWidth
                      chartWidth:(CGFloat)chartWidth
                     chartHeight:(CGFloat)chartHeight
                         padding:(CGFloat)padding
                   chartsPerRow:(NSInteger)chartsPerRow {
    
    CGFloat currentY = startY;
    NSInteger col = 0;
    NSInteger row = 0;
    
    for (NSString *symbol in symbols) {
        // Get historical data from cache
        NSArray<HistoricalBarModel *> *bars = self.lastScreeningCache[symbol];
        
        if (!bars || bars.count == 0) {
            NSLog(@"⚠️ No cached data for %@, skipping chart", symbol);
            
            // Draw placeholder
            CGFloat x = padding + col * (chartWidth + padding);
            CGFloat y = currentY - chartHeight;
            NSRect chartRect = NSMakeRect(x, y, chartWidth, chartHeight);
            
            [self drawPlaceholderChart:symbol inRect:chartRect];
        } else {
            // Render chart
            CGFloat x = padding + col * (chartWidth + padding);
            CGFloat y = currentY - chartHeight;
            NSRect chartRect = NSMakeRect(x, y, chartWidth, chartHeight);
            
            [self drawMiniChart:symbol withBars:bars inRect:chartRect];
        }
        
        col++;
        if (col >= chartsPerRow) {
            col = 0;
            row++;
            currentY -= (chartHeight + padding);
        }
    }
    
    // If we didn't complete the last row, move down
    if (col > 0) {
        currentY -= (chartHeight + padding);
    }
    
    return currentY;
}

- (void)drawMiniChart:(NSString *)symbol
             withBars:(NSArray<HistoricalBarModel *> *)bars
               inRect:(NSRect)rect {
    
    // Create temporary MiniChart
    MiniChart *miniChart = [[MiniChart alloc] initWithFrame:rect];
    miniChart.symbol = symbol;
    miniChart.chartType = MiniChartTypeCandle;  // ✅ CAMBIATO: Line → Candle
    miniChart.timeframe = MiniBarTimeframeDaily;
    miniChart.scaleType = MiniChartScaleLinear;
    miniChart.showVolume = YES;
    
    // Load data
    [miniChart updateWithHistoricalBars:bars];
    
    // Render to image
    NSImage *chartImage = [self renderMiniChartToImage:miniChart withSize:rect.size];
    
    if (chartImage) {
        [chartImage drawInRect:rect
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1.0];
    } else {
        [self drawPlaceholderChart:symbol inRect:rect];
    }
}

- (NSImage *)renderMiniChartToImage:(MiniChart *)miniChart withSize:(NSSize)size {
    if (!miniChart || size.width == 0 || size.height == 0) {
        return nil;
    }
    
    NSImage *image = [[NSImage alloc] initWithSize:size];
    [image lockFocus];
    
    // ✅ DARK MODE: Background scuro come i MiniChart
    [[NSColor colorWithWhite:0.2 alpha:1.0] setFill];
    NSRectFill(NSMakeRect(0, 0, size.width, size.height));
    
    // ✅ Bordo grigio per separare i chart
    [[NSColor colorWithWhite:0.35 alpha:1.0] setStroke];
    [NSBezierPath strokeRect:NSMakeRect(0, 0, size.width, size.height)];
    
    // Force redraw
    if (miniChart.priceData && miniChart.priceData.count > 0) {
        [miniChart setNeedsDisplay:YES];
        [miniChart displayIfNeeded];
        
        // Render view hierarchy
        NSBitmapImageRep *bitmapRep = [miniChart bitmapImageRepForCachingDisplayInRect:miniChart.bounds];
        [miniChart cacheDisplayInRect:miniChart.bounds toBitmapImageRep:bitmapRep];
        
        [bitmapRep drawInRect:NSMakeRect(1, 1, size.width - 2, size.height - 2)  // Inset per bordo
                     fromRect:NSZeroRect
                    operation:NSCompositingOperationSourceOver
                     fraction:1.0
               respectFlipped:YES
                        hints:nil];
    }
    
    [image unlockFocus];
    return image;
}

- (void)drawPlaceholderChart:(NSString *)symbol inRect:(NSRect)rect {
    // ✅ DARK MODE: Background grigio scuro
    [[NSColor colorWithWhite:0.22 alpha:1.0] setFill];
    NSRectFill(rect);
    
    // ✅ Bordo grigio
    [[NSColor colorWithWhite:0.35 alpha:1.0] setStroke];
    [NSBezierPath strokeRect:rect];
    
    // Symbol label
    NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
    centerStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.6 alpha:1.0],  // ✅ Grigio chiaro
        NSParagraphStyleAttributeName: centerStyle
    };
    
    NSString *text = [NSString stringWithFormat:@"%@\nNo Data", symbol];
    [text drawInRect:NSInsetRect(rect, 10, 10) withAttributes:attrs];
}

- (void)drawReportFooter:(NSRect)rect {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    NSString *timestamp = [NSString stringWithFormat:@"Generated: %@", [formatter stringFromDate:[NSDate date]]];
    
    NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
    centerStyle.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.5 alpha:1.0],  // ✅ Grigio medio
        NSParagraphStyleAttributeName: centerStyle
    };
    
    [timestamp drawInRect:rect withAttributes:attrs];
}

- (void)saveReportImage:(NSImage *)image selectedOnly:(BOOL)selectedOnly {
    // Generate filename
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *dateString = [formatter stringFromDate:[NSDate date]];
    
    NSString *filename = [NSString stringWithFormat:@"ScreenerReport_%@_%@.png",
                         dateString,
                         selectedOnly ? @"Selected" : @"All"];
    
    // Show save panel
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    savePanel.nameFieldStringValue = filename;
    savePanel.allowedFileTypes = @[@"png"];
    savePanel.title = @"Save Screener Report";
    
    [savePanel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            [self saveImage:image toURL:savePanel.URL];
        }
    }];
}

- (void)saveImage:(NSImage *)image toURL:(NSURL *)url {
    NSData *imageData = [self convertImageToPNG:image];
    NSError *error = nil;
    BOOL success = [imageData writeToURL:url options:NSDataWritingAtomic error:&error];
    
    if (success) {
        NSLog(@"✅ Report image saved: %@", url.path);
        [self showAlert:@"Success" message:@"Report saved successfully"];
    } else {
        NSLog(@"❌ Failed to save report: %@", error);
        [self showAlert:@"Error" message:[NSString stringWithFormat:@"Failed to save: %@", error.localizedDescription]];
    }
}

- (NSData *)convertImageToPNG:(NSImage *)image {
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    bitmapRep.size = image.size;
    return [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = title;
        alert.informativeText = message;
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    });
}

@end
