// ==========================================
// MiniChartCollectionItem.m - NUOVA CLASSE
// ==========================================
#import "MiniChartCollectionItem.h"

@implementation MiniChartCollectionItem

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // ✅ IMPORTANTE: Abilita la selezione
    self.view.wantsLayer = YES;
    if (self.view.layer) {
        self.view.layer.masksToBounds = YES;
        self.view.layer.cornerRadius = 4.0;
        self.view.layer.borderWidth = 0.0;
        self.view.layer.borderColor = [NSColor clearColor].CGColor;
    }
    
   
    
    NSLog(@"✅ MiniChartCollectionItem: Click gesture added");
}




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
    
    if (self.onSetupContextMenu) {
        self.onSetupContextMenu(miniChart);
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
