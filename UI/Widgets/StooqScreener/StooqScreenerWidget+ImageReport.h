// ============================================================================
// StooqScreenerWidget+ImageReport.h
// Category for generating image-based reports with MiniCharts
// ============================================================================

#import "StooqScreenerWidget.h"

NS_ASSUME_NONNULL_BEGIN

@interface StooqScreenerWidget (ImageReport)

// Generate image report with charts
- (void)generateImageReportWithSelectedOnly:(BOOL)selectedOnly;

@end

NS_ASSUME_NONNULL_END
