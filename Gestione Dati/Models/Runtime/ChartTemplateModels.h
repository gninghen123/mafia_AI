//
//  ChartTemplateModels.h
//  TradingApp
//
//  Runtime models for chart templates - UI layer, NOT Core Data
//  Thread-safe, performance-optimized models for template system
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class ChartPanelTemplateModel;
@class TechnicalIndicatorBase;

// =======================================
// CHART PANEL TEMPLATE MODEL - RUNTIME
// =======================================

@interface ChartPanelTemplateModel : NSObject

// Identification
@property (nonatomic, strong) NSString *panelID;
@property (nonatomic, strong, nullable) NSString *panelName;

// Layout properties
@property (nonatomic, assign) double relativeHeight;    // 0.0 to 1.0 (e.g., 0.8 = 80%)
@property (nonatomic, assign) NSInteger displayOrder;   // 0, 1, 2... for panel ordering

// Indicator configuration
@property (nonatomic, strong) NSString *rootIndicatorType;     // "SecurityIndicator", "VolumeIndicator", etc.
@property (nonatomic, strong, nullable) NSDictionary *rootIndicatorParams;  // Parameters for root indicator
@property (nonatomic, strong, nullable) NSArray *childIndicatorsData;       // Serialized child indicators

// Runtime properties (not persisted)
@property (nonatomic, strong, nullable) TechnicalIndicatorBase *rootIndicator;

// Factory methods
+ (instancetype)panelWithID:(NSString *)panelID
                       name:(nullable NSString *)name
            rootIndicatorType:(NSString *)rootType
                     height:(double)height
                      order:(NSInteger)order;

+ (instancetype)securityPanelWithHeight:(double)height order:(NSInteger)order;
+ (instancetype)volumePanelWithHeight:(double)height order:(NSInteger)order;
+ (instancetype)oscillatorPanelWithHeight:(double)height order:(NSInteger)order;

// Convenience methods
- (NSString *)displayName;
- (NSString *)rootIndicatorDisplayName;
- (BOOL)isSecurityPanel;
- (BOOL)isVolumePanel;
- (BOOL)isOscillatorPanel;

// Serialization/Deserialization
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

// Working copy (for editing without affecting original)
- (ChartPanelTemplateModel *)createWorkingCopy;
- (void)updateFromWorkingCopy:(ChartPanelTemplateModel *)workingCopy;

@end

// =======================================
// CHART TEMPLATE MODEL - RUNTIME
// =======================================

@interface ChartTemplateModel : NSObject

// Identification
@property (nonatomic, strong) NSString *templateID;
@property (nonatomic, strong) NSString *templateName;

// Status
@property (nonatomic, assign) BOOL isDefault;

// Timestamps
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *modifiedDate;

// Panels
@property (nonatomic, strong) NSMutableArray<ChartPanelTemplateModel *> *panels;

// Factory methods
+ (instancetype)templateWithName:(NSString *)name;
+ (instancetype)templateWithID:(NSString *)templateID name:(NSString *)name;

// Default template configurations
+ (instancetype)defaultSecurityVolumeTemplate;                    // 80% Security + 20% Volume
+ (instancetype)defaultSecurityVolumeOscillatorTemplate;         // 60% Security + 20% Volume + 20% Oscillator
+ (instancetype)defaultSecurityOnlyTemplate;                     // 100% Security

// Panel management
- (void)addPanel:(ChartPanelTemplateModel *)panel;
- (void)removePanel:(ChartPanelTemplateModel *)panel;
- (void)removePanelAtIndex:(NSUInteger)index;
- (void)insertPanel:(ChartPanelTemplateModel *)panel atIndex:(NSUInteger)index;
- (void)movePanelFromIndex:(NSUInteger)fromIndex toIndex:(NSUInteger)toIndex;

// Panel access
- (NSArray<ChartPanelTemplateModel *> *)orderedPanels;
- (ChartPanelTemplateModel * _Nullable)panelAtIndex:(NSUInteger)index;
- (ChartPanelTemplateModel * _Nullable)panelWithID:(NSString *)panelID;
- (ChartPanelTemplateModel * _Nullable)securityPanel;
- (ChartPanelTemplateModel * _Nullable)volumePanel;

// Validation
- (BOOL)isValid;
- (BOOL)isValidWithError:(NSError * _Nullable * _Nullable)error;
- (void)normalizeHeights;  // Ensure heights sum to 1.0

// Convenience methods
- (NSUInteger)panelCount;
- (double)totalHeight;
- (NSString *)panelSummary;  // "Security (80%) + Volume (20%)"

// Serialization/Deserialization
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dictionary;

// Working copy (for editing without affecting original)
- (ChartTemplateModel *)createWorkingCopy;
- (void)updateFromWorkingCopy:(ChartTemplateModel *)workingCopy;

// Template comparison
- (BOOL)isEqualToTemplate:(ChartTemplateModel *)otherTemplate;
- (NSComparisonResult)compareByName:(ChartTemplateModel *)otherTemplate;

@end

NS_ASSUME_NONNULL_END
