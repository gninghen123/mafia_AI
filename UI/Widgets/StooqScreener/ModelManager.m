//
//  ModelManager.m
//  TradingApp
//

#import "ModelManager.h"

@interface ModelManager ()
@property (nonatomic, strong) NSMutableArray<ScreenerModel *> *models;
@property (nonatomic, strong) NSMutableDictionary<NSString *, ScreenerModel *> *modelsByID;
@end

@implementation ModelManager

#pragma mark - Singleton

+ (instancetype)sharedManager {
    static ModelManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ModelManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _models = [NSMutableArray array];
        _modelsByID = [NSMutableDictionary dictionary];
        [self refreshModels];
    }
    return self;
}

#pragma mark - Model Directory

+ (NSString *)modelsDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = [paths firstObject];
    NSString *appDir = [appSupportDir stringByAppendingPathComponent:@"TradingApp"];
    return [appDir stringByAppendingPathComponent:@"ScreenerModels"];
}

+ (BOOL)ensureModelsDirectoryExists {
    NSString *dir = [self modelsDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:dir]) {
        NSError *error;
        BOOL success = [fm createDirectoryAtPath:dir
                     withIntermediateDirectories:YES
                                      attributes:nil
                                           error:&error];
        if (!success) {
            NSLog(@"❌ Failed to create models directory: %@", error.localizedDescription);
            return NO;
        }
        NSLog(@"✅ Created models directory: %@", dir);
    }
    
    return YES;
}

#pragma mark - Model Management

- (NSArray<ScreenerModel *> *)loadAllModels {
    [ModelManager ensureModelsDirectoryExists];
    
    NSString *dir = [ModelManager modelsDirectory];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error;
    
    NSArray *files = [fm contentsOfDirectoryAtPath:dir error:&error];
    if (!files) {
        NSLog(@"⚠️ Could not read models directory: %@", error.localizedDescription);
        return @[];
    }
    
    NSMutableArray *loadedModels = [NSMutableArray array];
    
    for (NSString *filename in files) {
        if (![filename hasSuffix:@".json"]) continue;
        
        NSString *filePath = [dir stringByAppendingPathComponent:filename];
        ScreenerModel *model = [ScreenerModel loadFromFile:filePath error:&error];
        
        if (model) {
            [loadedModels addObject:model];
            NSLog(@"✅ Loaded model: %@ (%@)", model.displayName, model.modelID);
        } else {
            NSLog(@"⚠️ Failed to load model from %@: %@", filename, error.localizedDescription);
        }
    }
    
    NSLog(@"📊 Loaded %lu models total", (unsigned long)loadedModels.count);
    return [loadedModels copy];
}

- (nullable ScreenerModel *)modelWithID:(NSString *)modelID {
    return self.modelsByID[modelID];
}

- (BOOL)saveModel:(ScreenerModel *)model error:(NSError **)error {
    if (![self validateModel:model error:error]) {
        return NO;
    }
    
    [ModelManager ensureModelsDirectoryExists];
    
    NSString *filename = [NSString stringWithFormat:@"%@.json", model.modelID];
    NSString *filePath = [[ModelManager modelsDirectory] stringByAppendingPathComponent:filename];
    
    model.modifiedAt = [NSDate date];
    
    BOOL success = [model saveToFile:filePath error:error];
    
    if (success) {
        // Update in-memory cache
        [self refreshModels];
        NSLog(@"✅ Saved model: %@ to %@", model.displayName, filename);
    } else {
        NSLog(@"❌ Failed to save model: %@", error ? (*error).localizedDescription : @"Unknown error");
    }
    
    return success;
}

- (BOOL)deleteModel:(NSString *)modelID error:(NSError **)error {
    NSString *filename = [NSString stringWithFormat:@"%@.json", modelID];
    NSString *filePath = [[ModelManager modelsDirectory] stringByAppendingPathComponent:filename];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL success = [fm removeItemAtPath:filePath error:error];
    
    if (success) {
        [self refreshModels];
        NSLog(@"✅ Deleted model: %@", modelID);
    } else {
        NSLog(@"❌ Failed to delete model: %@", error ? (*error).localizedDescription : @"Unknown error");
    }
    
    return success;
}

- (void)refreshModels {
    NSArray *loadedModels = [self loadAllModels];
    
    [self.models removeAllObjects];
    [self.modelsByID removeAllObjects];
    
    for (ScreenerModel *model in loadedModels) {
        [self.models addObject:model];
        self.modelsByID[model.modelID] = model;
    }
}

#pragma mark - Available Models

- (NSArray<ScreenerModel *> *)allModels {
    return [self.models copy];
}

- (NSArray<ScreenerModel *> *)enabledModels {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isEnabled == YES"];
    return [self.models filteredArrayUsingPredicate:predicate];
}

#pragma mark - Validation

- (BOOL)isModelIDAvailable:(NSString *)modelID {
    return self.modelsByID[modelID] == nil;
}

- (BOOL)validateModel:(ScreenerModel *)model error:(NSError **)error {
    if (!model.modelID || model.modelID.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ModelManagerError"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"Model ID is required"}];
        }
        return NO;
    }
    
    if (!model.displayName || model.displayName.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ModelManagerError"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"Display name is required"}];
        }
        return NO;
    }
    
    // Allow empty steps - user can add them in the editor
    // Validation will happen at execution time instead
    
    return YES;
}

@end
