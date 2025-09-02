//
// ChartTemplate+CoreDataClass.m
// TradingApp
//
// CoreData model implementation for chart templates
//

#import "ChartTemplate+CoreDataClass.h"
#import "ChartPanelTemplate+CoreDataClass.h"

@implementation ChartTemplate

// ❌ RIMUOVO TUTTI I @dynamic - Xcode li genererà automaticamente nei +CoreDataProperties files

#pragma mark - Convenience Methods

+ (instancetype)createWithName:(NSString *)name context:(NSManagedObjectContext *)context {
    ChartTemplate *template = [NSEntityDescription insertNewObjectForEntityForName:@"ChartTemplate"
                                                            inManagedObjectContext:context];
    
    template.templateID = [[NSUUID UUID] UUIDString];
    template.templateName = name;
    template.createdDate = [NSDate date];
    template.modifiedDate = [NSDate date];
    template.isDefault = NO;
    
    return template;
}

- (ChartTemplate *)createWorkingCopy {
    // Create a non-managed copy for editing
    ChartTemplate *workingCopy = [[ChartTemplate alloc] init];
    
    workingCopy.templateID = self.templateID;
    workingCopy.templateName = [self.templateName copy];
    workingCopy.createdDate = [self.createdDate copy];
    workingCopy.modifiedDate = [NSDate date]; // Update modification date
    workingCopy.isDefault = self.isDefault;
    
    // Copy panels
    NSMutableSet *copiedPanels = [[NSMutableSet alloc] init];
    for (ChartPanelTemplate *panel in self.panels) {
        ChartPanelTemplate *panelCopy = [panel createWorkingCopy];
        [copiedPanels addObject:panelCopy];
    }
    
    // Note: For working copy, we'll use setValue:forKey: to bypass Core Data validation
    [workingCopy setValue:copiedPanels forKey:@"panels"];
    
    return workingCopy;
}

- (void)updateFromWorkingCopy:(ChartTemplate *)workingCopy {
    self.templateName = workingCopy.templateName;
    self.modifiedDate = [NSDate date];
    self.isDefault = workingCopy.isDefault;
    
    // Clear existing panels - CORREZIONE: metodo corretto
    NSSet *existingPanels = [self.panels copy];
    [self removePanels:existingPanels];
    
    // Add updated panels
    for (ChartPanelTemplate *workingPanel in workingCopy.panels) {
        ChartPanelTemplate *managedPanel = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPanelTemplate"
                                                                         inManagedObjectContext:self.managedObjectContext];
        [managedPanel updateFromWorkingCopy:workingPanel];
        [self addPanelsObject:managedPanel];
    }
}

- (NSArray<ChartPanelTemplate *> *)orderedPanels {
    NSSortDescriptor *orderDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"displayOrder" ascending:YES];
    return [self.panels sortedArrayUsingDescriptors:@[orderDescriptor]];
}

#pragma mark - Validation

- (BOOL)validateTemplateID:(id *)valueRef error:(NSError **)outError {
    NSString *templateID = *valueRef;
    
    if (!templateID || templateID.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartTemplateValidation"
                                            code:1001
                                        userInfo:@{NSLocalizedDescriptionKey: @"Template ID cannot be empty"}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)validateTemplateName:(id *)valueRef error:(NSError **)outError {
    NSString *templateName = *valueRef;
    
    if (!templateName || templateName.length == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartTemplateValidation"
                                            code:1002
                                        userInfo:@{NSLocalizedDescriptionKey: @"Template name cannot be empty"}];
        }
        return NO;
    }
    
    if (templateName.length > 50) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"ChartTemplateValidation"
                                            code:1003
                                        userInfo:@{NSLocalizedDescriptionKey: @"Template name cannot exceed 50 characters"}];
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Core Data Lifecycle

- (void)awakeFromInsert {
    [super awakeFromInsert];
    
    if (!self.templateID) {
        self.templateID = [[NSUUID UUID] UUIDString];
    }
    
    NSDate *now = [NSDate date];
    if (!self.createdDate) {
        self.createdDate = now;
    }
    if (!self.modifiedDate) {
        self.modifiedDate = now;
    }
}

- (void)willSave {
    [super willSave];
    
    // Always update modification date when saving
    if (self.hasChanges && !self.isDeleted) {
        self.modifiedDate = [NSDate date];
    }
}

#pragma mark - Description

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %p> ID:%@ Name:'%@' Panels:%lu Default:%@",
            NSStringFromClass(self.class), self,
            self.templateID, self.templateName,
            (unsigned long)self.panels.count,
            self.isDefault ? @"YES" : @"NO"];
}

@end
