//
//  DataHub+ChartTemplates.h
//  TradingApp
//
//  NUOVA implementazione corretta per chart templates
//  ARCHITETTURA: Core Data interno, Runtime Models per UI
//  Thread-safe, performance-optimized
//

#import "DataHub.h"
#import "ChartTemplateModels.h"

NS_ASSUME_NONNULL_BEGIN

@interface DataHub (ChartTemplates)

#pragma mark - Template CRUD Operations (Runtime Models Only)

/// Get all available chart templates
/// @param completion Completion block with array of ChartTemplateModel (UI-ready)
- (void)getAllChartTemplates:(void(^)(NSArray<ChartTemplateModel *> *templates))completion;

/// Get default chart template (creates if doesn't exist)
/// @param completion Completion block with default ChartTemplateModel
- (void)getDefaultChartTemplate:(void(^)(ChartTemplateModel *defaultTemplate))completion;

/// Get specific template by ID
/// @param templateID Template identifier
/// @param completion Completion block with ChartTemplateModel or nil if not found
- (void)getChartTemplate:(NSString *)templateID
              completion:(void(^)(ChartTemplateModel * _Nullable template))completion;

/// Save chart template (create or update)
/// @param template ChartTemplateModel to save
/// @param completion Completion block with success status and updated template
- (void)saveChartTemplate:(ChartTemplateModel *)template
               completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable savedTemplate))completion;

/// Delete chart template by ID
/// @param templateID Template ID to delete
/// @param completion Completion block with success status
- (void)deleteChartTemplate:(NSString *)templateID
                 completion:(void(^)(BOOL success))completion;

#pragma mark - Template Management

/// Duplicate existing template with new name
/// @param sourceTemplateID Source template to duplicate
/// @param newName New name for duplicated template
/// @param completion Completion block with new ChartTemplateModel
- (void)duplicateChartTemplate:(NSString *)sourceTemplateID
                       newName:(NSString *)newName
                    completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable newTemplate))completion;

/// Set template as default (unsets previous default)
/// @param templateID Template to make default
/// @param completion Completion block with success status
- (void)setDefaultChartTemplate:(NSString *)templateID
                     completion:(void(^)(BOOL success))completion;

/// Check if default template exists
/// @param completion Completion block with existence status
- (void)defaultTemplateExists:(void(^)(BOOL exists))completion;

#pragma mark - Template Validation

/// Validate template model
/// @param template Template to validate
/// @return YES if template is valid for saving
- (BOOL)isValidChartTemplate:(ChartTemplateModel *)template;

/// Validate template with detailed error
/// @param template Template to validate
/// @param error Output error if validation fails
/// @return YES if template is valid
- (BOOL)validateChartTemplate:(ChartTemplateModel *)template error:(NSError * _Nullable * _Nullable)error;

#pragma mark - Import/Export (Runtime Models)

/// Export template to JSON data
/// @param template ChartTemplateModel to export
/// @param completion Completion block with JSON data
- (void)exportChartTemplate:(ChartTemplateModel *)template
                 completion:(void(^)(BOOL success, NSData * _Nullable jsonData))completion;

/// Import template from JSON data
/// @param jsonData JSON template data
/// @param completion Completion block with imported ChartTemplateModel
- (void)importChartTemplate:(NSData *)jsonData
                 completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable importedTemplate))completion;

#pragma mark - Template Statistics

/// Get template usage statistics
/// @param completion Completion block with statistics dictionary
- (void)getTemplateStatistics:(void(^)(NSDictionary<NSString *, NSNumber *> *stats))completion;

/// Mark template as recently used (for analytics)
/// @param templateID Template ID to mark
- (void)markTemplateAsUsed:(NSString *)templateID;

@end

NS_ASSUME_NONNULL_END
