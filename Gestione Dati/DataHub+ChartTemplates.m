//
// DataHub+ChartTemplates.m
// TradingApp
//
// DataHub extension implementation for chart templates management
//

#import "DataHub+ChartTemplates.h"
#import "ChartTemplate+CoreDataClass.h"
#import "ChartPanelTemplate+CoreDataClass.h"

// Import indicator classes for default template creation
// NOTE: These will need to be created/imported when they exist
// #import "SecurityIndicator.h"
// #import "VolumeIndicator.h"

@implementation DataHub (ChartTemplates)

#pragma mark - Template CRUD Operations

- (void)loadAllChartTemplates:(void(^)(NSArray<ChartTemplate *> *templates, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.sortDescriptors = @[
            [NSSortDescriptor sortDescriptorWithKey:@"isDefault" ascending:NO], // Default first
            [NSSortDescriptor sortDescriptorWithKey:@"templateName" ascending:YES]
        ];
        
        NSError *error;
        NSArray<ChartTemplate *> *templates = [context executeFetchRequest:request error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(templates ?: @[], error);
        });
    });
}

- (void)loadChartTemplate:(NSString *)templateID
               completion:(void(^)(ChartTemplate * _Nullable template, NSError * _Nullable error))completion {
    
    if (!templateID || templateID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"DataHubChartTemplates"
                                                 code:3001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Template ID is required"}];
            completion(nil, error);
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(results.firstObject, error);
        });
    });
}

- (void)saveChartTemplate:(ChartTemplate *)template
               completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!template) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"DataHubChartTemplates"
                                                 code:3002
                                             userInfo:@{NSLocalizedDescriptionKey: @"Template cannot be nil"}];
            completion(NO, error);
        });
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        // Find existing template or create new one
        ChartTemplate *managedTemplate = nil;
        if (template.templateID) {
            NSFetchRequest *request = [ChartTemplate fetchRequest];
            request.predicate = [NSPredicate predicateWithFormat:@"templateID == %@", template.templateID];
            request.fetchLimit = 1;
            
            NSArray *results = [context executeFetchRequest:request error:nil];
            managedTemplate = results.firstObject;
        }
        
        if (!managedTemplate) {
            // Create new template
            managedTemplate = [ChartTemplate createWithName:template.templateName context:context];
        }
        
        // Update from working copy
        [managedTemplate updateFromWorkingCopy:template];
        
        // Handle default template logic
        if (template.isDefault) {
            [self ensureOnlyOneDefaultTemplate:managedTemplate inContext:context];
        }
        
        // Save context
        NSError *error;
        BOOL success = [self saveContext:context error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    });
}

- (void)deleteChartTemplate:(NSString *)templateID
                 completion:(void(^)(BOOL success, NSError * _Nullable error))completion {
    
    if (!templateID || templateID.length == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSError *error = [NSError errorWithDomain:@"DataHubChartTemplates"
                                                 code:3003
                                             userInfo:@{NSLocalizedDescriptionKey: @"Template ID is required"}];
            completion(NO, error);
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
        ChartTemplate *templateToDelete = results.firstObject;
        
        if (!templateToDelete) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *notFoundError = [NSError errorWithDomain:@"DataHubChartTemplates"
                                                              code:3004
                                                          userInfo:@{NSLocalizedDescriptionKey: @"Template not found"}];
                completion(NO, notFoundError);
            });
            return;
        }
        
        // Prevent deletion of default template
        if (templateToDelete.isDefault) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError *defaultError = [NSError errorWithDomain:@"DataHubChartTemplates"
                                                             code:3005
                                                         userInfo:@{NSLocalizedDescriptionKey: @"Cannot delete default template"}];
                completion(NO, defaultError);
            });
            return;
        }
        
        [context deleteObject:templateToDelete];
        BOOL success = [self saveContext:context error:&error];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(success, error);
        });
    });
}

- (void)duplicateChartTemplate:(NSString *)sourceTemplateID
                       newName:(NSString *)newName
                    completion:(void(^)(ChartTemplate * _Nullable newTemplate, NSError * _Nullable error))completion {
    
    [self loadChartTemplate:sourceTemplateID completion:^(ChartTemplate *sourceTemplate, NSError *error) {
        if (error || !sourceTemplate) {
            completion(nil, error);
            return;
        }
        
        // Create working copy with new name
        ChartTemplate *duplicateTemplate = [sourceTemplate createWorkingCopy];
        duplicateTemplate.templateID = [[NSUUID UUID] UUIDString]; // New ID
        duplicateTemplate.templateName = newName;
        duplicateTemplate.isDefault = NO; // Duplicates are never default
        duplicateTemplate.createdDate = [NSDate date];
        duplicateTemplate.modifiedDate = [NSDate date];
        
        // Save the duplicate
        [self saveChartTemplate:duplicateTemplate completion:^(BOOL success, NSError *saveError) {
            completion(success ? duplicateTemplate : nil, saveError);
        }];
    }];
}

#pragma mark - Default Templates

- (void)getDefaultChartTemplate:(void(^)(ChartTemplate *defaultTemplate, NSError * _Nullable error))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES"];
        request.fetchLimit = 1;
        
        NSError *error;
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:&error];
        ChartTemplate *defaultTemplate = results.firstObject;
        
        if (!defaultTemplate) {
            // Create default template if it doesn't exist
            defaultTemplate = [self createDefaultTemplate];
            BOOL success = [self saveContext:context error:&error];
            
            if (!success) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
                return;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(defaultTemplate, error);
        });
    });
}

- (ChartTemplate *)createDefaultTemplate {
    NSManagedObjectContext *context = [self backgroundContext];
    
    // Create default template
    ChartTemplate *defaultTemplate = [ChartTemplate createWithName:@"Default" context:context];
    defaultTemplate.isDefault = YES;
    
    // Create Security Panel (66% height)
    ChartPanelTemplate *securityPanel = [ChartPanelTemplate createWithRootIndicatorType:@"SecurityIndicator"
                                                                              parameters:@{}
                                                                                 context:context];
    securityPanel.panelName = @"Security";
    securityPanel.relativeHeight = 0.66;
    securityPanel.displayOrder = 0;
    [defaultTemplate addPanelsObject:securityPanel];
    
    // Create Volume Panel (33% height)
    ChartPanelTemplate *volumePanel = [ChartPanelTemplate createWithRootIndicatorType:@"VolumeIndicator"
                                                                            parameters:@{}
                                                                               context:context];
    volumePanel.panelName = @"Volume";
    volumePanel.relativeHeight = 0.33;
    volumePanel.displayOrder = 1;
    [defaultTemplate addPanelsObject:volumePanel];
    
    NSLog(@"✅ Created default chart template with Security and Volume panels");
    
    return defaultTemplate;
}

- (void)defaultTemplateExists:(void(^)(BOOL exists))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSFetchRequest *request = [ChartTemplate fetchRequest];
        request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES"];
        request.fetchLimit = 1;
        
        NSUInteger count = [context countForFetchRequest:request error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(count > 0);
        });
    });
}

#pragma mark - Template Validation

- (BOOL)validateChartTemplate:(ChartTemplate *)template error:(NSError **)error {
    if (!template) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:4001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template cannot be nil"}];
        }
        return NO;
    }
    
    if (!template.templateName || template.templateName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:4002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template name cannot be empty"}];
        }
        return NO;
    }
    
    if (template.panels.count == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:4003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Template must have at least one panel"}];
        }
        return NO;
    }
    
    // Validate each panel
    for (ChartPanelTemplate *panel in template.panels) {
        if (![self validatePanelTemplate:panel error:error]) {
            return NO;
        }
    }
    
    // Validate height distribution
    double totalHeight = 0.0;
    for (ChartPanelTemplate *panel in template.panels) {
        totalHeight += panel.relativeHeight;
    }
    
    if (fabs(totalHeight - 1.0) > 0.01) { // Allow small floating point differences
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateValidation"
                                         code:4004
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Panel heights must sum to 1.0 (currently %.3f)", totalHeight]}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)validatePanelTemplate:(ChartPanelTemplate *)panelTemplate error:(NSError **)error {
    if (!panelTemplate) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                         code:5001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Panel template cannot be nil"}];
        }
        return NO;
    }
    
    if (!panelTemplate.panelID || panelTemplate.panelID.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                         code:5002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Panel ID cannot be empty"}];
        }
        return NO;
    }
    
    if (panelTemplate.relativeHeight <= 0.0 || panelTemplate.relativeHeight > 1.0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                         code:5003
                                     userInfo:@{NSLocalizedDescriptionKey: @"Panel relative height must be between 0.0 and 1.0"}];
        }
        return NO;
    }
    
    if (!panelTemplate.rootIndicatorType || panelTemplate.rootIndicatorType.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                         code:5004
                                     userInfo:@{NSLocalizedDescriptionKey: @"Panel must have a root indicator type"}];
        }
        return NO;
    }
    
    // Validate that the indicator class exists
    Class indicatorClass = NSClassFromString(panelTemplate.rootIndicatorType);
    if (!indicatorClass) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartPanelTemplateValidation"
                                         code:5005
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Unknown indicator class: %@", panelTemplate.rootIndicatorType]}];
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - Import/Export

- (NSData *)exportTemplate:(ChartTemplate *)template error:(NSError **)error {
    if (![self validateChartTemplate:template error:error]) {
        return nil;
    }
    
    NSMutableDictionary *exportDict = [[NSMutableDictionary alloc] init];
    
    // Template metadata
    exportDict[@"templateID"] = template.templateID;
    exportDict[@"templateName"] = template.templateName;
    exportDict[@"createdDate"] = @([template.createdDate timeIntervalSince1970]);
    exportDict[@"modifiedDate"] = @([template.modifiedDate timeIntervalSince1970]);
    exportDict[@"isDefault"] = @(template.isDefault);
    exportDict[@"exportVersion"] = @"1.0";
    
    // Panels data
    NSMutableArray *panelsArray = [[NSMutableArray alloc] init];
    NSArray<ChartPanelTemplate *> *orderedPanels = [template orderedPanels];
    
    for (ChartPanelTemplate *panel in orderedPanels) {
        NSMutableDictionary *panelDict = [[NSMutableDictionary alloc] init];
        
        panelDict[@"panelID"] = panel.panelID;
        panelDict[@"relativeHeight"] = @(panel.relativeHeight);
        panelDict[@"displayOrder"] = @(panel.displayOrder);
        panelDict[@"panelName"] = panel.panelName ?: [NSNull null];
        panelDict[@"rootIndicatorType"] = panel.rootIndicatorType;
        
        // Convert binary data to base64 for JSON compatibility
        if (panel.rootIndicatorParams) {
            panelDict[@"rootIndicatorParams"] = [panel.rootIndicatorParams base64EncodedStringWithOptions:0];
        }
        if (panel.childIndicatorsData) {
            panelDict[@"childIndicatorsData"] = [panel.childIndicatorsData base64EncodedStringWithOptions:0];
        }
        
        [panelsArray addObject:panelDict];
    }
    
    exportDict[@"panels"] = panelsArray;
    
    // Convert to JSON
    return [NSJSONSerialization dataWithJSONObject:exportDict
                                           options:NSJSONWritingPrettyPrinted
                                             error:error];
}

- (ChartTemplate *)importTemplateFromJSON:(NSData *)jsonData error:(NSError **)error {
    NSDictionary *importDict = [NSJSONSerialization JSONObjectWithData:jsonData
                                                               options:0
                                                                 error:error];
    if (!importDict) {
        return nil;
    }
    
    // Validate import version
    NSString *exportVersion = importDict[@"exportVersion"];
    if (!exportVersion || ![exportVersion isEqualToString:@"1.0"]) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChartTemplateImport"
                                         code:6001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unsupported template export version"}];
        }
        return nil;
    }
    
    NSManagedObjectContext *context = [self backgroundContext];
    
    // Create new template
    ChartTemplate *template = [ChartTemplate createWithName:importDict[@"templateName"] context:context];
    template.templateID = importDict[@"templateID"] ?: [[NSUUID UUID] UUIDString];
    
    // Import dates
    NSNumber *createdTimestamp = importDict[@"createdDate"];
    NSNumber *modifiedTimestamp = importDict[@"modifiedDate"];
    if (createdTimestamp) {
        template.createdDate = [NSDate dateWithTimeIntervalSince1970:[createdTimestamp doubleValue]];
    }
    if (modifiedTimestamp) {
        template.modifiedDate = [NSDate dateWithTimeIntervalSince1970:[modifiedTimestamp doubleValue]];
    }
    
    template.isDefault = [importDict[@"isDefault"] boolValue];
    
    // Import panels
    NSArray *panelsArray = importDict[@"panels"];
    for (NSDictionary *panelDict in panelsArray) {
        ChartPanelTemplate *panel = [ChartPanelTemplate createWithRootIndicatorType:panelDict[@"rootIndicatorType"]
                                                                          parameters:@{}
                                                                             context:context];
        
        panel.panelID = panelDict[@"panelID"];
        panel.relativeHeight = [panelDict[@"relativeHeight"] doubleValue];
        panel.displayOrder = [panelDict[@"displayOrder"] intValue];
        
        id panelName = panelDict[@"panelName"];
        if (panelName && ![panelName isKindOfClass:[NSNull class]]) {
            panel.panelName = panelName;
        }
        
        // Convert base64 back to binary data
        NSString *rootParamsBase64 = panelDict[@"rootIndicatorParams"];
        if (rootParamsBase64) {
            panel.rootIndicatorParams = [[NSData alloc] initWithBase64EncodedString:rootParamsBase64 options:0];
        }
        
        NSString *childDataBase64 = panelDict[@"childIndicatorsData"];
        if (childDataBase64) {
            panel.childIndicatorsData = [[NSData alloc] initWithBase64EncodedString:childDataBase64 options:0];
        }
        
        [template addPanelsObject:panel];
    }
    
    // Validate imported template
    if (![self validateChartTemplate:template error:error]) {
        return nil;
    }
    
    return template;
}

#pragma mark - Template Statistics

- (void)getTemplateUsageStatistics:(void(^)(NSDictionary<NSString *, NSNumber *> *stats))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *context = [self backgroundContext];
        
        NSMutableDictionary *stats = [[NSMutableDictionary alloc] init];
        
        // Total templates count
        NSFetchRequest *allTemplatesRequest = [ChartTemplate fetchRequest];
        NSUInteger totalCount = [context countForFetchRequest:allTemplatesRequest error:nil];
        stats[@"totalTemplates"] = @(totalCount);
        
        // Default templates count (should be 1)
        NSFetchRequest *defaultTemplatesRequest = [ChartTemplate fetchRequest];
        defaultTemplatesRequest.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES"];
        NSUInteger defaultCount = [context countForFetchRequest:defaultTemplatesRequest error:nil];
        stats[@"defaultTemplates"] = @(defaultCount);
        
        // Custom templates count
        stats[@"customTemplates"] = @(totalCount - defaultCount);
        
        // Average panels per template
        NSFetchRequest *allPanelsRequest = [ChartPanelTemplate fetchRequest];
        NSUInteger totalPanels = [context countForFetchRequest:allPanelsRequest error:nil];
        stats[@"totalPanels"] = @(totalPanels);
        stats[@"averagePanelsPerTemplate"] = totalCount > 0 ? @((double)totalPanels / totalCount) : @0;
        
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
        
        NSArray<ChartTemplate *> *results = [context executeFetchRequest:request error:nil];
        ChartTemplate *template = results.firstObject;
        
        if (template) {
            template.modifiedDate = [NSDate date]; // Update as "last used"
            [self saveContext:context error:nil];
        }
    });
}

#pragma mark - Private Helper Methods

- (void)ensureOnlyOneDefaultTemplate:(ChartTemplate *)newDefault inContext:(NSManagedObjectContext *)context {
    // Remove default flag from all other templates
    NSFetchRequest *request = [ChartTemplate fetchRequest];
    request.predicate = [NSPredicate predicateWithFormat:@"isDefault == YES AND templateID != %@", newDefault.templateID];
    
    NSArray<ChartTemplate *> *otherDefaults = [context executeFetchRequest:request error:nil];
    for (ChartTemplate *otherDefault in otherDefaults) {
        otherDefault.isDefault = NO;
        NSLog(@"🔄 Removed default flag from template: %@", otherDefault.templateName);
    }
    
    NSLog(@"✅ Set '%@' as the only default template", newDefault.templateName);
}

- (BOOL)saveContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if (![context hasChanges]) return YES;
    
    __block BOOL success = NO;
    __block NSError *saveError = nil;
    
    [context performBlockAndWait:^{
        success = [context save:&saveError];
        
        if (success) {
            NSLog(@"✅ Chart template context saved successfully");
        } else {
            NSLog(@"❌ Failed to save chart template context: %@", saveError);
        }
    }];
    
    if (error) *error = saveError;
    return success;
}

- (NSManagedObjectContext *)backgroundContext {
    // Reuse existing DataHub background context method
    return [self newBackgroundContext];
}

@end
