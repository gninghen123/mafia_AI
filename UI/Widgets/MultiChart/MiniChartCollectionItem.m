// ==========================================
// MiniChartCollectionItem.m - NUOVA CLASSE
// ==========================================
#import "MiniChartCollectionItem.h"

@implementation MiniChartCollectionItem

- (void)loadView {
    // ✅ FIX: Crea sempre una view container, mai riutilizzare direttamente MiniChart
    NSView *containerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 150)];
    containerView.wantsLayer = YES;
    containerView.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    self.view = containerView;
}

- (void)configureMiniChart:(MiniChart *)miniChart {
    if (!miniChart) {
        NSLog(@"❌ configureMiniChart: miniChart is nil!");
        return;
    }
    
    // ✅ FIX: Rimuovi MiniChart precedente se esiste
    if (self.miniChart) {
        [self.miniChart removeFromSuperview];
        NSLog(@"🔄 Removed previous miniChart for reuse");
    }
    
    self.miniChart = miniChart;
    
    // ✅ FIX: Aggiungi il MiniChart alla view container
    [self.view addSubview:miniChart];
    miniChart.translatesAutoresizingMaskIntoConstraints = NO;
    
    // ✅ FIX: Constraint per riempire completamente il container
    [NSLayoutConstraint activateConstraints:@[
        [miniChart.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [miniChart.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [miniChart.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [miniChart.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    
    NSLog(@"📦 MiniChart configured: %@ in collection item", miniChart.symbol ?: @"nil");
    
    // Setup dei callback esistenti usando i pattern attuali
    if (self.onChartClicked) {
        // Rimuovi gesture recognizer esistenti per evitare duplicati
        NSArray *existingGestures = [miniChart.gestureRecognizers copy];
        for (NSGestureRecognizer *recognizer in existingGestures) {
            if ([recognizer isKindOfClass:[NSClickGestureRecognizer class]]) {
                [miniChart removeGestureRecognizer:recognizer];
            }
        }
        
        // Aggiungi nuovo gesture recognizer
        NSClickGestureRecognizer *clickGesture = [[NSClickGestureRecognizer alloc]
                                                  initWithTarget:self
                                                  action:@selector(chartClicked:)];
        [miniChart addGestureRecognizer:clickGesture];
    }
    
    if (self.onSetupContextMenu) {
        self.onSetupContextMenu(miniChart);
    }
}

- (void)chartClicked:(NSClickGestureRecognizer *)gesture {
    NSLog(@"👆 Chart clicked in collection item: %@", self.miniChart.symbol ?: @"nil");
    if (self.onChartClicked && self.miniChart) {
        self.onChartClicked(self.miniChart);
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    // ✅ FIX: Pulisci per il riuso
    if (self.miniChart) {
        [self.miniChart removeFromSuperview];
        self.miniChart = nil;
    }
    
    self.onChartClicked = nil;
    self.onSetupContextMenu = nil;
    
    NSLog(@"♻️ MiniChartCollectionItem prepared for reuse");
}

@end
