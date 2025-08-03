//
//  DataHub+TickDataProperties.h
//  mafia_AI
//
//  Dynamic properties for tick data using associated objects
//

#import "DataHub.h"
#import "TickDataModel.h"

@interface DataHub (TickDataProperties)

// Dynamic properties for tick data management
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<TickDataModel *> *> *tickDataCache;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDate *> *tickCacheTimestamps;
@property (nonatomic, strong) NSMutableSet<NSString *> *activeTickStreams;
@property (nonatomic, strong) NSTimer *tickStreamTimer;

@end

