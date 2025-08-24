// IBKRLoginManager.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IBKRLoginManager : NSObject

+ (instancetype)sharedManager;

// Main integration method for IBKRDataSource
- (void)ensureClientPortalReadyWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;

// Configuration
@property (nonatomic, strong) NSString *clientPortalPath;  // Auto-detected or manually set
@property (nonatomic, assign) BOOL autoLaunchEnabled;      // Default YES
@property (nonatomic, assign) NSInteger port;              // Client Portal port

@end

NS_ASSUME_NONNULL_END
