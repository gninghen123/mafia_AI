// ========================================================================
// StorageMetadataCache.h
// Sistema di cache in memoria per metadata degli storage files
// ========================================================================

#import <Foundation/Foundation.h>
#import "SavedChartData.h"

NS_ASSUME_NONNULL_BEGIN

@interface StorageMetadataItem : NSObject

// File info
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, strong) NSString *filename;
@property (nonatomic, assign) NSTimeInterval fileModificationTime;
@property (nonatomic, assign) NSInteger fileSizeBytes;

// Parsed metadata
@property (nonatomic, strong) NSString *symbol;
@property (nonatomic, strong) NSString *timeframe;
@property (nonatomic, assign) SavedChartDataType dataType;
@property (nonatomic, assign) NSInteger barCount;
@property (nonatomic, strong, nullable) NSDate *startDate;
@property (nonatomic, strong, nullable) NSDate *endDate;
@property (nonatomic, strong, nullable) NSDate *creationDate;
@property (nonatomic, strong, nullable) NSDate *lastUpdate;
@property (nonatomic, assign) BOOL includesExtendedHours;
@property (nonatomic, assign) BOOL hasGaps;

// Runtime info
@property (nonatomic, assign) BOOL isNewFormat;
@property (nonatomic, assign) NSTimeInterval cacheTime;

// Convenience properties
@property (nonatomic, readonly) BOOL isContinuous;
@property (nonatomic, readonly) BOOL isSnapshot;
@property (nonatomic, readonly) NSString *displayName;
@property (nonatomic, readonly) NSString *dateRangeString;

// Factory methods
+ (instancetype)itemFromFilePath:(NSString *)filePath;
+ (instancetype)itemFromDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;

// Update methods
- (BOOL)updateFromFilesystem;
- (BOOL)needsRefreshFromFilesystem;

@end

@interface StorageMetadataCache : NSObject

// Singleton
+ (instancetype)sharedCache;

// Cache management
- (void)buildCacheFromDirectory:(NSString *)directory;
- (void)addOrUpdateItem:(StorageMetadataItem *)item;
- (void)removeItemForPath:(NSString *)filePath;
- (void)removeItemForFilename:(NSString *)filename;

// Query methods
@property (nonatomic, readonly) NSArray<StorageMetadataItem *> *allItems;
@property (nonatomic, readonly) NSArray<StorageMetadataItem *> *continuousItems;
@property (nonatomic, readonly) NSArray<StorageMetadataItem *> *snapshotItems;
@property (nonatomic, readonly) NSInteger totalCount;

- (nullable StorageMetadataItem *)itemForPath:(NSString *)filePath;
- (nullable StorageMetadataItem *)itemForFilename:(NSString *)filename;
- (NSArray<StorageMetadataItem *> *)itemsForSymbol:(NSString *)symbol;

// File operations callbacks
- (void)handleFileCreated:(NSString *)filePath;
- (void)handleFileUpdated:(NSString *)filePath;
- (void)handleFileDeleted:(NSString *)filePath;
- (void)handleFileRenamed:(NSString *)oldPath newPath:(NSString *)newPath;

// Consistency check
- (void)performConsistencyCheck:(NSString *)directory completion:(void(^)(NSInteger inconsistencies))completion;

// Persistence
- (void)saveToUserDefaults;
- (void)loadFromUserDefaults;
- (void)clearCache;

// Statistics
- (NSDictionary *)cacheStatistics;

@end

NS_ASSUME_NONNULL_END


