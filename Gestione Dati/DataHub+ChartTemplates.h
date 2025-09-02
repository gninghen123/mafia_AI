//
// DataHub+ChartTemplates.h
// TradingApp
//
// DataHub extension for chart templates management
//

#import "DataHub.h"
#import "ChartTemplate+CoreDataClass.h"
#import "ChartPanelTemplate+CoreDataClass.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (ChartTemplates)

#pragma mark - Template CRUD Operations

/// Load all available chart templates
/// @param completion Completion block with templates array
- (void)loadAllChartTemplates:(void(^)(NSArray<ChartTemplate *> *templates, NSError * _Nullable error))completion;

/// Load specific template by ID
/// @param templateID Unique template identifier
/// @param completion Completion block with template
- (void)loadChartTemplate:(NSString *)templateID
               completion:(void(^)(ChartTemplate * _Nullable template, NSError * _Nullable error))completion;

/// Save chart template (create or update)
/// @param template Template to save
/// @param completion Completion block with success status
- (void)saveChartTemplate:(ChartTemplate *)template
               completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Delete chart template
/// @param templateID Template ID to delete
/// @param completion Completion block with success status
- (void)deleteChartTemplate:(NSString *)templateID
                 completion:(void(^)(BOOL success, NSError * _Nullable error))completion;

/// Duplicate template with new name
/// @param sourceTemplateID Source template to copy
/// @param newName Name for the duplicate
/// @param completion Completion block with new template
- (void)duplicateChartTemplate:(NSString *)sourceTemplateID
                       newName:(NSString *)newName
                    completion:(void(^)(ChartTemplate * _Nullable newTemplate, NSError * _Nullable error))completion;

#pragma mark - Default Templates

/// Get or create the default template
/// @param completion Completion block with default template
- (void)getDefaultChartTemplate:(void(^)(ChartTemplate *defaultTemplate, NSError * _Nullable error))completion;

/// Create default template (Security + Volume panels)
/// @return Default template configuration
- (ChartTemplate *)createDefaultTemplate;

/// Check if default template exists
/// @param completion Completion block with existence status
- (void)defaultTemplateExists:(void(^)(BOOL exists))completion;

#pragma mark - Template Validation

/// Validate template structure and data
/// @param template Template to validate
/// @param error Error pointer for validation failures
/// @return YES if template is valid
- (BOOL)validateChartTemplate:(ChartTemplate *)template error:(NSError **)error;

/// Validate panel template
/// @param panelTemplate Panel to validate
/// @param error Error pointer for validation failures
/// @return YES if panel is valid
- (BOOL)validatePanelTemplate:(ChartPanelTemplate *)panelTemplate error:(NSError **)error;

#pragma mark - Import/Export

/// Export template to JSON
/// @param template Template to export
/// @param error Error pointer for export failures
/// @return JSON data or nil if failed
- (NSData * _Nullable)exportTemplate:(ChartTemplate *)template error:(NSError **)error;

/// Import template from JSON
/// @param jsonData JSON template data
/// @param error Error pointer for import failures
/// @return Imported template or nil if failed
- (ChartTemplate * _Nullable)importTemplateFromJSON:(NSData *)jsonData error:(NSError **)error;

#pragma mark - Template Statistics

/// Get usage statistics for templates
/// @param completion Completion block with statistics
- (void)getTemplateUsageStatistics:(void(^)(NSDictionary<NSString *, NSNumber *> *stats))completion;

/// Mark template as recently used
/// @param templateID Template to mark
- (void)markTemplateAsUsed:(NSString *)templateID;

@end

NS_ASSUME_NONNULL_END
