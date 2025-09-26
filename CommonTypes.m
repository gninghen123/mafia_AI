#import "CommonTypes.h"

@implementation CommonTypes

#pragma mark - Directory Management

+ (NSString *)savedChartDataDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *appSupportDir = paths.firstObject;
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
    return [[appSupportDir stringByAppendingPathComponent:appName] stringByAppendingPathComponent:@"SavedChartData"];
}

+ (BOOL)ensureSavedChartDataDirectoryExists:(NSError **)error {
    NSString *directory = [self savedChartDataDirectory];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (![fileManager fileExistsAtPath:directory]) {
        return [fileManager createDirectoryAtPath:directory
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:error];
    }
    return YES;
}

@end
