// ==========================================
// MiniChartCollectionItem.m - NUOVA CLASSE
// ==========================================
#import "MiniChartCollectionItem.h"

@implementation MiniChartCollectionItem

- (void)loadView {
    // Usa il MiniChart esistente come view principale
    if (self.miniChart) {
        self.view = self.miniChart;
    } else {
        // Placeholder se non ancora configurato
        self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 200)];
        self.view.wantsLayer = YES;
        self.view.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    }
}

- (void)configureMiniChart:(MiniChart *)miniChart {
    self.miniChart = miniChart;
    
    // Se la view è già stata caricata, sostituiscila
    if (self.viewLoaded) {
        self.view = miniChart;
    }
    
    // Setup dei callback esistenti usando i pattern attuali
    if (self.onChartClicked) {
        // Rimuovi gesture recognizer esistenti per evitare duplicati
        for (NSGestureRecognizer *recognizer in miniChart.gestureRecognizers) {
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
    if (self.onChartClicked && self.miniChart) {
        self.onChartClicked(self.miniChart);
    }
}

@end
