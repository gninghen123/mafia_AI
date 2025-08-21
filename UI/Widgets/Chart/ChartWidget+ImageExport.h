//
//  ChartWidget+ImageExport.h
//  TradingApp
//
//  Extension per l'esportazione di immagini del chart
//

#import "ChartWidget.h"

NS_ASSUME_NONNULL_BEGIN

@interface ChartWidget (ImageExport)

#pragma mark - Image Export

/// Create chart image and save to chartImages directory
- (void)createChartImageInteractive;

/// Create chart image programmatically
/// @param completion Completion block with success status and file path
- (void)createChartImage:(void(^)(BOOL success, NSString * _Nullable filePath, NSError * _Nullable error))completion;

#pragma mark - Directory Management

/// Get the default directory for chart images
+ (NSString *)chartImagesDirectory;

/// Ensure the chart images directory exists
+ (BOOL)ensureChartImagesDirectoryExists:(NSError **)error;

#pragma mark - Context Menu Integration

/// Add create image menu item to existing context menu
- (void)addImageExportMenuItemToMenu:(NSMenu *)menu;

#pragma mark - Context Menu Actions

/// Context menu action for creating image
- (IBAction)contextMenuCreateImage:(id)sender;

@end

NS_ASSUME_NONNULL_END
