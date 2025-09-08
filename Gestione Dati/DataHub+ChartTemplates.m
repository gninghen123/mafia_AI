//
//  DataHub+ChartTemplates.m
//  TradingApp
//
//  NUOVA implementazione corretta per chart templates
//  ARCHITETTURA: Core Data interno, Runtime Models per UI
//

#import "DataHub+ChartTemplates.h"
#import "ChartTemplate+CoreDataClass.h"
#import "ChartPanelTemplate+CoreDataClass.h"

@implementation DataHub (ChartTemplates)

#pragma mark - Template CRUD Operations

- (void)getAllChartTemplates:(void(^)(NSArray<ChartTemplateModel *> *templates))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"isDefault" ascending:NO], // Default first
            [NSSortDescriptor sortDescriptorWithKey:@"templateName" ascending:YES]
        ];
        
        NSError *error;
        NSArray<ChartTemplate *> *coreDataTemplates = [context executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch templates: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(@[]);
            });
            return;
        }
        
        // ✅ Convert Core Data -> Runtime Models
        NSMutableArray<ChartTemplateModel *> *runtimeTemplates = [NSMutableArray array];
        for (ChartTemplate *coreDataTemplate in coreDataTemplates) {
            ChartTemplateModel *runtimeModel = [self runtimeModelFromCoreData:coreDataTemplate];
            if (runtimeModel) {
                [runtimeTemplates addObject:runtimeModel];
            }
        }
        
        NSLog(@"✅ DataHub: Loaded %ld chart templates", (long)runtimeTemplates.count);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([runtimeTemplates copy]);
        });
    });
}

- (void)getDefaultChartTemplate:(void(^)(ChartTemplateModel *defaultTemplate))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        // Try to find existing default template
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES"];
        request.fetchLimit = 1;
        
        NSError *error;
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
        
        ChartTemplate *coreDataTemplate = results.firstObject;
        
        if (!coreDataTemplate) {
            // ✅ Create default template if doesn't exist
            NSLog(@"🏗️ DataHub: Creating default template (Security 80% + Volume 20%)");
            coreDataTemplate = [self createDefaultCoreDataTemplate:context];
            
            // Save the new default template
            if (![context save:&error]) {
                NSLog(@"❌ DataHub: Failed to save default template: %@", error.localizedDescription);
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil);
                });
                return;
            }
        }
        
        // ✅ Convert Core Data -> Runtime Model
        ChartTemplateModel *runtimeModel = [self runtimeModelFromCoreData:coreDataTemplate];
        
        NSLog(@"✅ DataHub: Default template ready: %@", runtimeModel.templateName);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeModel);
        });
    });
}

- (void)getChartTemplate:(NSString *)templateID
              completion:(void(^)(ChartTemplateModel * _Nullable template))completion {
    
    if (!templateID || templateID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"templateID == %@", templateID];
        request.fetchLimit = 1;
        
        NSError *error;
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
        
        if (error) {
            NSLog(@"❌ DataHub: Failed to fetch template %@: %@", templateID, error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
            return;
        }
        
        ChartTemplate *coreDataTemplate = results.firstObject;
        ChartTemplateModel *runtimeModel = nil;
        
        if (coreDataTemplate) {
            // ✅ Convert Core Data -> Runtime Model
            runtimeModel = [self runtimeModelFromCoreData:coreDataTemplate];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(runtimeModel);
        });
    });
}

- (void)saveChartTemplate:(ChartTemplateModel *)template
               completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable savedTemplate))completion {
    
    if (![self validateChartTemplate:template error:nil]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, nil);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        // Find existing template or create new
        ChartTemplate *coreDataTemplate = [self findOrCreateCoreDataTemplate:template context:context];
        
        // ✅ Convert Runtime Model -> Core Data
        [self updateCoreDataTemplate:coreDataTemplate fromRuntimeModel:template];
        
        // Handle default template logic
        if (template.isDefault) {
            [self ensureOnlyOneDefaultTemplate:coreDataTemplate inContext:context];
        }
        
        // Save
        NSError *error;
        BOOL success = [context save:&error];
        
        if (success) {
            NSLog(@"✅ DataHub: Saved template: %@", template.templateName);
            
            // ✅ Convert back to Runtime Model with updated data
            ChartTemplateModel *savedRuntimeModel = [self runtimeModelFromCoreData:coreDataTemplate];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, savedRuntimeModel);
            });
        } else {
            NSLog(@"❌ DataHub: Failed to save template: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
            });
        }
    });
}

- (void)deleteChartTemplate:(NSString *)templateID
                 completion:(void(^)(BOOL success))completion {
    
    if (!templateID || templateID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"templateID == %@", templateID];
        request.fetchLimit = 10;
        
        NSError *error;
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
        
        if (error || results.count == 0) {
            NSLog(@"❌ DataHub: Template not found for deletion: %@", templateID);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
            return;
        }
        
        ChartTemplate *coreDataTemplate = results.firstObject;
        
        // Prevent deletion of default template
        if (coreDataTemplate.isDefault) {
            NSLog(@"❌ DataHub: Cannot delete default template: %@", templateID);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO);
            });
            return;
        }
        
        NSString *templateName = coreDataTemplate.templateName;
        [context deleteObject:coreDataTemplate];
        
        BOOL success = [context save:&error];
        
        if (success) {
            NSLog(@"✅ DataHub: Deleted template: %@", templateName);
        } else {
            NSLog(@"❌ DataHub: Failed to delete template: %@", error.localizedDescription);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success);
        });
    });
}

#pragma mark - Template Management

- (void)duplicateChartTemplate:(NSString *)sourceTemplateID
                       newName:(NSString *)newName
                    completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable newTemplate))completion {
    
    [self getChartTemplate:sourceTemplateID completion:^(ChartTemplateModel *sourceTemplate) {
        if (!sourceTemplate) {
            completion(NO, nil);
            return;
        }
        
        // Create working copy with new ID and name
        ChartTemplateModel *duplicateTemplate = [sourceTemplate createWorkingCopy];
        duplicateTemplate.templateID = [[NSUUID UUID] UUIDString];
        duplicateTemplate.templateName = newName;
        duplicateTemplate.isDefault = NO; // Duplicates are never default
        duplicateTemplate.createdDate = [NSDate date];
        duplicateTemplate.modifiedDate = [NSDate date];
        
        // Assign new IDs to all panels
        for (ChartPanelTemplateModel *panel in duplicateTemplate.panels) {
            panel.panelID = [[NSUUID UUID] UUIDString];
        }
        
        // Save the duplicate
        [self saveChartTemplate:duplicateTemplate completion:^(BOOL success, ChartTemplateModel *savedTemplate) {
            if (success) {
                NSLog(@"✅ DataHub: Duplicated template '%@' -> '%@'", sourceTemplate.templateName, newName);
            }
            completion(success, savedTemplate);
        }];
    }];
}

- (void)setDefaultChartTemplate:(NSString *)templateID
                     completion:(void(^)(BOOL success))completion {
    
    [self getChartTemplate:templateID completion:^(ChartTemplateModel *template) {
        if (!template) {
            completion(NO);
            return;
        }
        
        template.isDefault = YES;
        template.modifiedDate = [NSDate date];
        
        [self saveChartTemplate:template completion:^(BOOL success, ChartTemplateModel *savedTemplate) {
            if (success) {
                NSLog(@"✅ DataHub: Set default template: %@", template.templateName);
            }
            completion(success);
        }];
    }];
}

- (void)defaultTemplateExists:(void(^)(BOOL exists))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES"];
        
        NSError *error;
        NSUInteger count = [context countForFetchRequest:request error:&error];
        
        BOOL exists = (count > 0 && !error);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(exists);
        });
    });
}

#pragma mark - Template Validation

- (BOOL)isValidChartTemplate:(ChartTemplateModel *)template {
    return [self validateChartTemplate:template error:nil];
}

- (BOOL)validateChartTemplate:(ChartTemplateModel *)template error:(NSError **)error {
    if (!template) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template cannot be nil"}];
        }
        return NO;
    }
    
    if (!template.templateName || template.templateName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template name cannot be empty"}];
        }
        return NO;
    }
    
    // Use built-in validation from runtime model
    return [template isValidWithError:error];
}

#pragma mark - Import/Export

- (void)exportChartTemplate:(ChartTemplateModel *)template
                 completion:(void(^)(BOOL success, NSData * _Nullable jsonData))completion {
    
    if (![self validateChartTemplate:template error:nil]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, nil);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Use runtime model's built-in serialization
        NSDictionary *templateDict = [template toDictionary];
        
        // Add export metadata
        NSMutableDictionary *exportDict = [templateDict mutableCopy];
        exportDict[@"exportVersion"] = @"1.0";
        exportDict[@"exportDate"] = @([[NSDate date] timeIntervalSince1970]);
        
        NSError *error;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:exportDict
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&error];
        
        BOOL success = (jsonData != nil && !error);
        if (success) {
            NSLog(@"✅ DataHub: Exported template: %@", template.templateName);
        } else {
            NSLog(@"❌ DataHub: Failed to export template: %@", error.localizedDescription);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, jsonData);
        });
    });
}

- (void)importChartTemplate:(NSData *)jsonData
                 completion:(void(^)(BOOL success, ChartTemplateModel * _Nullable importedTemplate))completion {
    
    if (!jsonData) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(NO, nil);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error;
        NSDictionary *importDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                   options:0
                                                                     error:&error];
        
        if (error || !importDict) {
            NSLog(@"❌ DataHub: Failed to parse import JSON: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
            });
            return;
        }
        
        // Validate export version
        NSString *exportVersion = importDict[@"exportVersion"];
        if (!exportVersion || ![exportVersion isEqualToString:@"1.0"]) {
            NSLog(@"❌ DataHub: Unsupported export version: %@", exportVersion);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
            });
            return;
        }
        
        // Create runtime model from dictionary
        ChartTemplateModel *importedTemplate = [ChartTemplateModel fromDictionary:importDict];
        
        if (![self validateChartTemplate:importedTemplate error:&error]) {
            NSLog(@"❌ DataHub: Invalid imported template: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, nil);
            });
            return;
        }
        
        // Assign new ID and mark as non-default
        importedTemplate.templateID = [[NSUUID UUID] UUIDString];
        importedTemplate.isDefault = NO;
        importedTemplate.createdDate = [NSDate date];
        importedTemplate.modifiedDate = [NSDate date];
        
        // Assign new IDs to all panels
        for (ChartPanelTemplateModel *panel in importedTemplate.panels) {
            panel.panelID = [[NSUUID UUID] UUIDString];
        }
        
        NSLog(@"✅ DataHub: Imported template: %@", importedTemplate.templateName);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(YES, importedTemplate);
        });
    });
}

#pragma mark - Template Statistics

- (void)getTemplateStatistics:(void(^)(NSDictionary<NSString *, NSNumber *> *stats))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        NSError *error;
        NSArray<ChartTemplate *> *templates = [context executeFetchRequest:request error:&error];
        
        NSMutableDictionary *stats = [NSMutableDictionary dictionary];
        
        if (!error) {
            stats[@"totalTemplates"] = @(templates.count);
            stats[@"defaultTemplates"] = @([templates filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isDefault == YES"]].count);
            stats[@"customTemplates"] = @([templates filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isDefault == NO"]].count);
            
            // Calculate average panels per template
            NSUInteger totalPanels = 0;
            for (ChartTemplate *template in templates) {
                totalPanels += template.panels.count;
            }
            stats[@"avgPanelsPerTemplate"] = templates.count > 0 ? @((double)totalPanels / templates.count) : @0;
        } else {
            NSLog(@"❌ DataHub: Failed to get template statistics: %@", error.localizedDescription);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion([stats copy]);
        });
    });
}

- (void)markTemplateAsUsed:(NSString *)templateID {
    if (!templateID) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"templateID == %@", templateID];
        request.fetchLimit = 1;
        
        NSError *error;
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
        
        if (!error && results.count > 0) {
            ChartTemplate *template = results.firstObject;
            template.modifiedDate = [NSDate date]; // Mark as recently used
            [context save:nil];
        }
    });
}

#pragma mark - Private: Core Data Conversion Methods

- (ChartTemplateModel *)runtimeModelFromCoreData:(ChartTemplate *)coreDataTemplate {
    if (!coreDataTemplate) return nil;
    
    ChartTemplateModel *runtimeModel = [[ChartTemplateModel alloc] init];
    
    // Basic properties
    runtimeModel.templateID = coreDataTemplate.templateID;
    runtimeModel.templateName = coreDataTemplate.templateName;
    runtimeModel.isDefault = coreDataTemplate.isDefault;
    runtimeModel.createdDate = coreDataTemplate.createdDate;
    runtimeModel.modifiedDate = coreDataTemplate.modifiedDate;
    
    // Convert panels
    NSArray<ChartPanelTemplate *> *orderedCoreDataPanels = [coreDataTemplate orderedPanels];
    for (ChartPanelTemplate *coreDataPanel in orderedCoreDataPanels) {
        ChartPanelTemplateModel *runtimePanel = [self runtimePanelModelFromCoreData:coreDataPanel];
        if (runtimePanel) {
            [runtimeModel addPanel:runtimePanel];
        }
    }
    
    return runtimeModel;
}

- (ChartPanelTemplateModel *)runtimePanelModelFromCoreData:(ChartPanelTemplate *)coreDataPanel {
    if (!coreDataPanel) return nil;
    
    ChartPanelTemplateModel *runtimePanel = [[ChartPanelTemplateModel alloc] init];
    
    runtimePanel.panelID = coreDataPanel.panelID;
    runtimePanel.panelName = coreDataPanel.panelName;
    runtimePanel.relativeHeight = coreDataPanel.relativeHeight;
    runtimePanel.displayOrder = coreDataPanel.displayOrder;
    runtimePanel.rootIndicatorType = coreDataPanel.rootIndicatorType;
    
    // Convert binary data to dictionary
    if (coreDataPanel.rootIndicatorParams) {
        NSError *error;
        id params = [NSJSONSerialization JSONObjectWithData:coreDataPanel.rootIndicatorParams
                                                    options:0
                                                      error:&error];
        if (!error && [params isKindOfClass:[NSDictionary class]]) {
            runtimePanel.rootIndicatorParams = params;
        }
    }
    
    if (coreDataPanel.childIndicatorsData) {
        NSError *error;
        id childData = [NSJSONSerialization JSONObjectWithData:coreDataPanel.childIndicatorsData
                                                       options:0
                                                         error:&error];
        if (!error && [childData isKindOfClass:[NSArray class]]) {
            runtimePanel.childIndicatorsData = childData;
        }
    }
    
    return runtimePanel;
}

- (ChartTemplate *)findOrCreateCoreDataTemplate:(ChartTemplateModel *)runtimeModel
                                         context:(NSManagedObjectContext *)context {
    
    // Try to find existing template
    NSFetchRequest *request = [ChartTemplate fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"templateID == %@", runtimeModel.templateID];
    request.fetchLimit = 1;
    
    NSError *error;
    NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
    
    ChartTemplate *coreDataTemplate = results.firstObject;
    
    if (!coreDataTemplate) {
        // Create new
        coreDataTemplate = [NSEntityDescription insertNewObjectForEntityForName:@"ChartTemplate"
                                                         inManagedObjectContext:context];
        coreDataTemplate.templateID = runtimeModel.templateID;
        coreDataTemplate.createdDate = runtimeModel.createdDate;
    }
    
    return coreDataTemplate;
}

- (void)updateCoreDataTemplate:(ChartTemplate *)coreDataTemplate
               fromRuntimeModel:(ChartTemplateModel *)runtimeModel {
    
    // Update basic properties
    coreDataTemplate.templateName = runtimeModel.templateName;
    coreDataTemplate.isDefault = runtimeModel.isDefault;
    coreDataTemplate.modifiedDate = runtimeModel.modifiedDate;
    
    // Clear existing panels
    NSSet *existingPanels = [coreDataTemplate.panels copy];
    [coreDataTemplate removePanels:existingPanels];
    
    // Add panels from runtime model
    for (ChartPanelTemplateModel *runtimePanel in runtimeModel.panels) {
        ChartPanelTemplate *coreDataPanel = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPanelTemplate"
                                                                           inManagedObjectContext:coreDataTemplate.managedObjectContext];
        
        [self updateCoreDataPanel:coreDataPanel fromRuntimeModel:runtimePanel];
        [coreDataTemplate addPanelsObject:coreDataPanel];
    }
}

- (void)updateCoreDataPanel:(ChartPanelTemplate *)coreDataPanel
            fromRuntimeModel:(ChartPanelTemplateModel *)runtimePanel {
    
    coreDataPanel.panelID = runtimePanel.panelID;
    coreDataPanel.panelName = runtimePanel.panelName;
    coreDataPanel.relativeHeight = runtimePanel.relativeHeight;
    coreDataPanel.displayOrder = runtimePanel.displayOrder;
    coreDataPanel.rootIndicatorType = runtimePanel.rootIndicatorType;
    
    // Convert dictionary to binary data
    if (runtimePanel.rootIndicatorParams) {
        NSError *error;
        NSData *paramsData = [NSJSONSerialization dataWithJSONObject:runtimePanel.rootIndicatorParams
                                                             options:0
                                                               error:&error];
        if (!error) {
            coreDataPanel.rootIndicatorParams = paramsData;
        }
    }
    
    if (runtimePanel.childIndicatorsData) {
        NSError *error;
        NSData *childData = [NSJSONSerialization dataWithJSONObject:runtimePanel.childIndicatorsData
                                                            options:0
                                                              error:&error];
        if (!error) {
            coreDataPanel.childIndicatorsData = childData;
        }
    }
}

- (ChartTemplate *)createDefaultCoreDataTemplate:(NSManagedObjectContext *)context {
    // Create Core Data template
    ChartTemplate *coreDataTemplate = [NSEntityDescription insertNewObjectForEntityForName:@"ChartTemplate"
                                                                     inManagedObjectContext:context];
    
    coreDataTemplate.templateID = [[NSUUID UUID] UUIDString];
    coreDataTemplate.templateName = @"Default";
    coreDataTemplate.isDefault = YES;
    coreDataTemplate.createdDate = [NSDate date];
    coreDataTemplate.modifiedDate = [NSDate date];
    
    // Create Security Panel (80%)
    ChartPanelTemplate *securityPanel = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPanelTemplate"
                                                                       inManagedObjectContext:context];
    securityPanel.panelID = [[NSUUID UUID] UUIDString];
    securityPanel.panelName = @"Security";
    securityPanel.rootIndicatorType = @"SecurityIndicator";
    securityPanel.relativeHeight = 0.80;
    securityPanel.displayOrder = 0;
    
    // Empty parameters as JSON
    securityPanel.rootIndicatorParams = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
    securityPanel.childIndicatorsData = [NSJSONSerialization dataWithJSONObject:@[] options:0 error:nil];
    
    [coreDataTemplate addPanelsObject:securityPanel];
    
    // Create Volume Panel (20%)
    ChartPanelTemplate *volumePanel = [NSEntityDescription insertNewObjectForEntityForName:@"ChartPanelTemplate"
                                                                     inManagedObjectContext:context];
    volumePanel.panelID = [[NSUUID UUID] UUIDString];
    volumePanel.panelName = @"Volume";
    volumePanel.rootIndicatorType = @"VolumeIndicator";
    volumePanel.relativeHeight = 0.20;
    volumePanel.displayOrder = 1;
    
    // Empty parameters as JSON
    volumePanel.rootIndicatorParams = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];
    volumePanel.childIndicatorsData = [NSJSONSerialization dataWithJSONObject:@[] options:0 error:nil];
    
    [coreDataTemplate addPanelsObject:volumePanel];
    
    NSLog(@"✅ DataHub: Created default Core Data template - Security (80%) + Volume (20%)");
    
    return coreDataTemplate;
}

- (void)ensureOnlyOneDefaultTemplate:(ChartTemplate *)newDefault
                           inContext:(NSManagedObjectContext *)context {
    
    // Find all other default templates and unset them
    NSFetchRequest *request = [ChartTemplate fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES AND templateID != %@", newDefault.templateID];
    
    NSError *error;
    NSArray<ChartTemplate *> *otherDefaults = [context executeFetchRequest:request error:&error];
    
    if (!error) {
        for (ChartTemplate *otherDefault in otherDefaults) {
            otherDefault.isDefault = NO;
            NSLog(@"🔄 DataHub: Removed default flag from template: %@", otherDefault.templateName);
        }
    }
    
    NSLog(@"✅ DataHub: Set '%@' as the only default template", newDefault.templateName);
}

- (NSManagedObjectContext *)backgroundContext {
    NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    backgroundContext.parentContext = self.mainContext;
    return backgroundContext;
}

@end
