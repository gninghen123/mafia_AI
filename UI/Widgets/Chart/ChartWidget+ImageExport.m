//
//  ChartWidget+ImageExport.m
//  TradingApp
//
//  Implementation for chart image export
//

#import "ChartWidget+ImageExport.h"
#import "ChartPanelView.h" // Import necessario per risolvere forward declaration

// Forward declaration per accedere a metodi privati di ChartWidget+SaveData
@interface ChartWidget (SaveDataPrivate)
- (NSString *)formatDateForDisplay:(NSDate *)date;
@end
// Forward declaration per accedere a metodi privati di ChartPanelView
@interface ChartPanelView (ImageExportPrivate)
- (void)drawChartContent;
- (void)drawYAxisContent;
- (void)drawEmptyState;
- (void)drawCandlesticks;
- (void)drawVolumeHistogram;
@end

@implementation ChartWidget (ImageExport)

#pragma mark - Image Export

- (void)createChartImageInteractive {
    [self createChartImage:^(BOOL success, NSString *filePath, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success && filePath) {
                // Show success alert
                NSAlert *successAlert = [[NSAlert alloc] init];
                successAlert.messageText = @"Chart Image Created";
                successAlert.informativeText = [NSString stringWithFormat:@"Image saved successfully:\n%@", [filePath lastPathComponent]];
                [successAlert addButtonWithTitle:@"OK"];
                [successAlert runModal];
                
                // Open Finder with the chartImages directory
                NSString *imagesDirectory = [ChartWidget chartImagesDirectory];
                [[NSWorkspace sharedWorkspace] openFile:imagesDirectory];
                
                NSLog(@"✅ Chart image created and Finder opened: %@", filePath);
            } else {
                // Show error alert
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Image Creation Failed";
                errorAlert.informativeText = error.localizedDescription ?: @"Unknown error occurred";
                [errorAlert addButtonWithTitle:@"OK"];
                [errorAlert runModal];
                
                NSLog(@"❌ Chart image creation failed: %@", error.localizedDescription);
            }
        });
    }];
}

- (void)createChartImage:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    // Validate current state
    if (!self.currentSymbol || self.chartPanels.count == 0) {
        NSError *error = [NSError errorWithDomain:@"ChartImageExport" code:1001
                                         userInfo:@{NSLocalizedDescriptionKey: @"No chart data available to export"}];
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Ensure directory exists
    NSError *error;
    if (![ChartWidget ensureChartImagesDirectoryExists:&error]) {
        if (completion) completion(NO, nil, error);
        return;
    }
    
    // Temporarily hide crosshair on all panels during capture
    NSMutableArray *originalCrosshairStates = [NSMutableArray array];
    for (ChartPanelView *panel in self.chartPanels) {
        [originalCrosshairStates addObject:@(panel.crosshairVisible)];
        [panel setCrosshairPoint:panel.crosshairPoint visible:NO];
    }
    
    // Small delay to ensure UI updates
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performImageCaptureWithCompletion:^(BOOL success, NSString *filePath, NSError *captureError) {
            // Restore crosshair states
            for (NSInteger i = 0; i < self.chartPanels.count && i < originalCrosshairStates.count; i++) {
                ChartPanelView *panel = self.chartPanels[i];
                BOOL originalState = [originalCrosshairStates[i] boolValue];
                [panel setCrosshairPoint:panel.crosshairPoint visible:originalState];
            }
            
            if (completion) completion(success, filePath, captureError);
        }];
    });
}

- (void)performImageCaptureWithCompletion:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion {
    @try {
        // Use panelsSplitView for capturing - it contains all the panels
        NSView *splitView = self.panelsSplitView;
        if (!splitView || splitView.bounds.size.width == 0 || splitView.bounds.size.height == 0) {
            NSError *error = [NSError errorWithDomain:@"ChartImageExport" code:1002
                                             userInfo:@{NSLocalizedDescriptionKey: @"Invalid split view dimensions"}];
            if (completion) completion(NO, nil, error);
            return;
        }
        
        // Add space for text overlay (symbol, timeframe, dates)
        CGFloat textOverlayHeight = 60;
        CGSize imageSize = NSMakeSize(splitView.bounds.size.width, splitView.bounds.size.height + textOverlayHeight);
        
        // Create image representation
        NSImage *combinedImage = [[NSImage alloc] initWithSize:imageSize];
        
        [combinedImage lockFocus];
        
        // Fill background
        [[NSColor controlBackgroundColor] setFill];
        [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, imageSize.width, imageSize.height)] fill];
        
        // Draw text overlay at the top
        [self drawTextOverlayInRect:NSMakeRect(0, splitView.bounds.size.height, imageSize.width, textOverlayHeight)];
        
        // 🔧 FIXED: Render each panel manually to capture CALayer content
        CGFloat yOffset = 0;
        for (NSInteger i = self.chartPanels.count - 1; i >= 0; i--) {
            ChartPanelView *panel = self.chartPanels[i];
            
            // Create offscreen image for this panel with layer content
            NSImage *panelImage = [self renderPanelToImage:panel];
            
            if (panelImage) {
                [panelImage drawInRect:NSMakeRect(0, yOffset, panel.bounds.size.width, panel.bounds.size.height)];
                yOffset += panel.bounds.size.height;
            }
        }
        
        [combinedImage unlockFocus];
        
        // Generate filename
        NSString *filename = [self generateImageFilename];
        NSString *imagesDirectory = [ChartWidget chartImagesDirectory];
        NSString *filePath = [imagesDirectory stringByAppendingPathComponent:filename];
        
        // Convert to PNG and save
        NSData *imageData = [self convertImageToPNG:combinedImage];
        BOOL saveSuccess = [imageData writeToFile:filePath atomically:YES];
        
        if (saveSuccess) {
            NSLog(@"✅ Chart image saved: %@", filePath);
            if (completion) completion(YES, filePath, nil);
        } else {
            NSError *saveError = [NSError errorWithDomain:@"ChartImageExport" code:1003
                                                 userInfo:@{NSLocalizedDescriptionKey: @"Failed to save image file"}];
            if (completion) completion(NO, nil, saveError);
        }
        
    } @catch (NSException *exception) {
        NSError *error = [NSError errorWithDomain:@"ChartImageExport" code:1004
                                         userInfo:@{NSLocalizedDescriptionKey: exception.reason}];
        if (completion) completion(NO, nil, error);
    }
}

// 🆕 NEW: Method to render a panel with its CALayers to an image
- (NSImage *)renderPanelToImage:(ChartPanelView *)panel {
    if (!panel || panel.bounds.size.width == 0 || panel.bounds.size.height == 0) {
        return nil;
    }
    
    NSSize panelSize = panel.bounds.size;
    NSImage *panelImage = [[NSImage alloc] initWithSize:panelSize];
    
    [panelImage lockFocus];
    
    // Fill panel background
    [[NSColor controlBackgroundColor] setFill];
    [[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, panelSize.width, panelSize.height)] fill];
    
    // Manually render layer content by triggering the drawing methods
    // This bypasses the CALayer system and renders directly to the current graphics context
    
    // 1. Render chart content
    if (panel.chartContentLayer && panel.chartData && panel.chartData.count > 0) {
        [self renderLayerContent:panel forLayerType:@"chartContent"];
    }
    
    // 2. Render Y-axis
    if (panel.yAxisLayer) {
        [self renderLayerContent:panel forLayerType:@"yAxis"];
    }
    
    // 3. Render objects if present (but not crosshair since it's hidden)
    if (panel.objectRenderer && panel.objectRenderer.objectsLayer) {
        [self renderLayerContent:panel forLayerType:@"objects"];
    }
    
    // 4. Render alerts if present
    if (panel.alertRenderer && panel.alertRenderer.alertsLayer) {
        [self renderLayerContent:panel forLayerType:@"alerts"];
    }
    
    // Skip crosshair layer since it's temporarily hidden
    
    [panelImage unlockFocus];
    
    return panelImage;
}

// 🆕 NEW: Helper method to render specific layer content
- (void)renderLayerContent:(ChartPanelView *)panel forLayerType:(NSString *)layerType {
    @try {
        // Call the appropriate drawing method directly
        if ([layerType isEqualToString:@"chartContent"]) {
            [panel drawChartContent];
        } else if ([layerType isEqualToString:@"yAxis"]) {
            if ([panel respondsToSelector:@selector(drawYAxisContent)]) {
                [panel performSelector:@selector(drawYAxisContent)];
            }
        } else if ([layerType isEqualToString:@"objects"]) {
            // Render objects through their renderer
            if (panel.objectRenderer && [panel.objectRenderer respondsToSelector:@selector(renderAllObjects)]) {
                [panel.objectRenderer performSelector:@selector(renderAllObjects)];
            }
        } else if ([layerType isEqualToString:@"alerts"]) {
            // Render alerts through their renderer
            if (panel.alertRenderer && [panel.alertRenderer respondsToSelector:@selector(renderAllAlerts)]) {
                [panel.alertRenderer performSelector:@selector(renderAllAlerts)];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"⚠️ Failed to render layer %@ for panel %@: %@", layerType, panel.panelType, exception.reason);
    }
}

- (void)drawTextOverlayInRect:(NSRect)rect {
    // Background for text overlay
    [[NSColor colorWithWhite:0.0 alpha:0.7] setFill];
    [[NSBezierPath bezierPathWithRect:rect] fill];
    
    // Get date range from visible data using currentChartData method
    NSString *startDate = @"N/A";
    NSString *endDate = @"N/A";
    
    NSArray<HistoricalBarModel *> *chartData = [self currentChartData];
    if (chartData && self.visibleStartIndex >= 0 &&
        self.visibleEndIndex < chartData.count && self.visibleStartIndex <= self.visibleEndIndex) {
        HistoricalBarModel *startBar = chartData[self.visibleStartIndex];
        HistoricalBarModel *endBar = chartData[self.visibleEndIndex];
        
        startDate = [self formatDateForDisplay:startBar.date];
        endDate = [self formatDateForDisplay:endBar.date];
    }
    
    // Symbol and timeframe (larger font, first line)
    NSString *symbolTimeframe = [NSString stringWithFormat:@"%@ · %@",
                                self.currentSymbol, [self timeframeToString:self.currentTimeframe]];
    
    NSDictionary *symbolAttrs = @{
        NSFontAttributeName: [NSFont boldSystemFontOfSize:18],
        NSForegroundColorAttributeName: [NSColor whiteColor]
    };
    
    // Date range (smaller font, second line)
    NSString *dateRange = [NSString stringWithFormat:@"%@ — %@", startDate, endDate];
    
    NSDictionary *dateAttrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:12],
        NSForegroundColorAttributeName: [NSColor colorWithWhite:0.9 alpha:1.0]
    };
    
    // Draw text in top-left with padding
    CGFloat padding = 12;
    CGFloat lineHeight = 22;
    
    NSPoint symbolPoint = NSMakePoint(rect.origin.x + padding, rect.origin.y + rect.size.height - padding - lineHeight);
    [symbolTimeframe drawAtPoint:symbolPoint withAttributes:symbolAttrs];
    
    NSPoint datePoint = NSMakePoint(rect.origin.x + padding, rect.origin.y + rect.size.height - padding - (lineHeight * 2));
    [dateRange drawAtPoint:datePoint withAttributes:dateAttrs];
}

- (NSString *)generateImageFilename {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    
    NSString *timeframeString = [self timeframeToString:self.currentTimeframe];
    
    return [NSString stringWithFormat:@"%@_%@_%@.png",
            self.currentSymbol, timeframeString, timestamp];
}

- (NSData *)convertImageToPNG:(NSImage *)image {
    CGImageRef cgImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
    return [bitmapRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

#pragma mark - Directory Management

+ (NSString *)chartImagesDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = paths.firstObject;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return [[appSupportDir stringByAppendingPathComponent:appName] stringByAppendingPathComponent:@"chartImages"];
}

+ (BOOL)ensureChartImagesDirectoryExists:(NSError **)error {
    NSString *directory = [self chartImagesDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:directory]) {
        return [fileManager createDirectoryAtPath:directory
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:error];
    }
    return YES;
}

#pragma mark - Context Menu Integration

- (void)addImageExportMenuItemToMenu:(NSMenu *)menu {
    // Add separator before image export
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Create image menu item
    NSMenuItem *createImageItem = [[NSMenuItem alloc] initWithTitle:@"📸 Crea Immagine"
                                                             action:@selector(contextMenuCreateImage:)
                                                      keyEquivalent:@""];
    createImageItem.target = self;
    createImageItem.enabled = (self.currentSymbol != nil && self.chartPanels.count > 0);
    [menu addItem:createImageItem];
}

#pragma mark - Context Menu Actions

- (IBAction)contextMenuCreateImage:(id)sender {
    [self createChartImageInteractive];
}

- (NSString *)timeframeToString:(ChartTimeframe)timeframe {
    switch (timeframe) {
        case ChartTimeframe1Min: return @"1min";
        case ChartTimeframe5Min: return @"5min";
        case ChartTimeframe15Min: return @"15min";
        case ChartTimeframe30Min: return @"30min";
        case ChartTimeframe1Hour: return @"1hour";
        case ChartTimeframe4Hour: return @"4hour";
        case ChartTimeframeDaily: return @"daily";
        case ChartTimeframeWeekly: return @"weekly";
        case ChartTimeframeMonthly: return @"monthly";
        default: return @"unknown";
    }
}
@end
