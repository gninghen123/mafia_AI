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

// Fix per ChartTemplate+CoreDataClass.m - metodo willSave

- (void)willSave {
    [super willSave];
    
    // ✅ CORREZIONE: Solo aggiorna modifiedDate se ci sono altri cambiamenti oltre a modifiedDate stesso
    if (self.hasChanges && !self.isDeleted) {
        // Controlla se ci sono cambiamenti oltre a modifiedDate
        NSArray *changedKeys = [[self changedValues] allKeys];  // Questo è un NSArray
        
        // Se gli unici cambiamenti sono su modifiedDate, NON aggiornare di nuovo
        // per evitare loop infinito
        if (changedKeys.count == 1 && [changedKeys.firstObject isEqualToString:@"modifiedDate"]) {
            NSLog(@"⏭️ ChartTemplate: Skipping modifiedDate update to avoid infinite loop");
            return;
        }
        
        // Ci sono altri cambiamenti oltre a modifiedDate, quindi è sicuro aggiornarlo
        NSDate *now = [NSDate date];
        
        // Controlla se modifiedDate è già uguale a "now" (per evitare micro-loop)
        if (!self.modifiedDate || [self.modifiedDate timeIntervalSinceDate:now] < -1.0) {
            self.modifiedDate = now;
            NSLog(@"📝 ChartTemplate: Updated modifiedDate for template '%@'", self.templateName);
        }
    }
}

// ✅ ALTERNATIVA PIÙ SICURA: Disabilitare completamente l'auto-update di modifiedDate
- (void)willSave_SAFE_VERSION {
    [super willSave];
    
    // NON aggiornare automaticamente modifiedDate in willSave
    // Lasciamo che sia il codice application-level a gestire modifiedDate
    // Questo previene loop infiniti
    NSLog(@"💾 ChartTemplate: willSave called for template '%@' (no auto-update of modifiedDate)", self.templateName);
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
