//
//  ScoreTableWidget_Private.h
//  TradingApp
//
//  Private interface for ScoreTableWidget categories
//

#import "ScoreTableWidget.h"

NS_ASSUME_NONNULL_BEGIN

@interface ScoreTableWidget ()

// Private properties accessible to categories
@property (nonatomic, strong) NSMutableArray<NSString *> *currentSymbols;
@property (nonatomic, assign) BOOL isCalculating;

// ✅ AGGIUNGI: Progress UI methods
- (void)showLoadingUI;
- (void)hideLoadingUI;
- (void)updateProgress:(NSInteger)current total:(NSInteger)total;

@end

NS_ASSUME_NONNULL_END
