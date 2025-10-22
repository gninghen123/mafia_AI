//
// ChartIndicatorRenderer.m
// TradingApp
//
// ✅ REFACTORED: NSBezierPath-based rendering with CALayer delegate pattern
//

#import "ChartIndicatorRenderer.h"
#import "ChartPanelView.h"
#import "SharedXCoordinateContext.h"
#import "PanelYCoordinateContext.h"
#import "RuntimeModels.h"
#import "TechnicalIndicatorBase+Hierarchy.h"
#import "rawdataseriesindicator.h"

static const CGFloat SIMPLIFIED_DRAWING_THRESHOLD = 1.0f;
static NSColor *SIMPLIFIED_DRAWING_COLOR = nil;


@implementation ChartIndicatorRenderer

#pragma mark - Initialization

- (instancetype)initWithPanelView:(ChartPanelView *)panelView {
    if (self = [super init]) {
        _panelView = panelView;
      
        _activeWarnings = [[NSMutableArray alloc] init];
        [self setupIndicatorsLayer];
        [self setupWarningMessagesLayer];
        SIMPLIFIED_DRAWING_COLOR = [NSColor labelColor]; // Colore neutro standard

        NSLog(@"🎨 ChartIndicatorRenderer: Initialized for panel: %@", panelView.panelType);
    }
    return self;
}

#pragma mark - Layer Management (UPDATED)

- (void)setupIndicatorsLayer {
    self.indicatorsLayer = [CALayer layer];
    self.indicatorsLayer.delegate = self;
    self.indicatorsLayer.needsDisplayOnBoundsChange = YES;
    
    [self.panelView.layer insertSublayer:self.indicatorsLayer above:self.panelView.chartContentLayer];
    [self updateLayerBounds];
    
    NSLog(@"📊 ChartIndicatorRenderer: Indicators layer setup completed");
}

// 🆕 NEW: Setup warning messages layer
- (void)setupWarningMessagesLayer {
    self.warningMessagesLayer = [CATextLayer layer];
    self.warningMessagesLayer.fontSize = 10.0;
    self.warningMessagesLayer.foregroundColor = [NSColor systemOrangeColor].CGColor;
    self.warningMessagesLayer.backgroundColor = [[NSColor systemOrangeColor] colorWithAlphaComponent:0.1].CGColor;
    self.warningMessagesLayer.borderColor = [NSColor systemOrangeColor].CGColor;
    self.warningMessagesLayer.borderWidth = 1.0;
    self.warningMessagesLayer.cornerRadius = 4.0;
    self.warningMessagesLayer.alignmentMode = kCAAlignmentLeft;
    self.warningMessagesLayer.wrapped = YES;
    self.warningMessagesLayer.hidden = YES; // Hidden by default
    
    [self.panelView.layer insertSublayer:self.warningMessagesLayer above:self.indicatorsLayer];
    [self updateWarningMessagesLayerFrame];
    
    NSLog(@"⚠️ ChartIndicatorRenderer: Warning messages layer setup completed");
}

- (void)updateLayerBounds {
    if (self.indicatorsLayer) {
        self.indicatorsLayer.frame = self.panelView.bounds;
    }
    [self updateWarningMessagesLayerFrame];
}

// 🆕 NEW: Update warning messages layer position (bottom left)
- (void)updateWarningMessagesLayerFrame {
    if (!self.warningMessagesLayer) return;
    
    CGFloat warningWidth = 150;
    CGFloat warningHeight = 24;
    CGFloat margin = 10;
    
    CGRect warningFrame = CGRectMake(margin,
                                   margin,
                                   warningWidth,
                                   warningHeight);
    
    self.warningMessagesLayer.frame = warningFrame;
}

#pragma mark - Template Configuration (NEW)

- (void)configureWithPanelTemplate:(ChartPanelTemplateModel *)panelTemplate {
    if (!panelTemplate) {
        NSLog(@"❌ IndicatorRenderer: Cannot configure with nil panel template");
        return;
    }
    
    NSLog(@"🏗️ IndicatorRenderer: Configuring with template: %@ (%@)",
          [panelTemplate displayName], panelTemplate.rootIndicatorType);
    
    // ✅ STEP 1: Create root indicator from template data
    TechnicalIndicatorBase *rootIndicator = [self createRootIndicatorFromTemplate:panelTemplate];
    
    if (!rootIndicator) {
        NSLog(@"❌ Failed to create root indicator from template: %@", panelTemplate.rootIndicatorType);
        return;
    }
    
    // ✅ STEP 2: Configure child indicators if present
    if (panelTemplate.childIndicatorsData && panelTemplate.childIndicatorsData.count > 0) {
        [self configureChildIndicators:panelTemplate.childIndicatorsData forRootIndicator:rootIndicator];
    }
    
    // ✅ STEP 3: Store the configured indicator
    self.rootIndicator = rootIndicator;
    
    
    NSLog(@"✅ IndicatorRenderer configured with root indicator: %@", rootIndicator.displayName);
}


#pragma mark - Helper Methods (NEW)

- (TechnicalIndicatorBase *)createRootIndicatorFromTemplate:(ChartPanelTemplateModel *)panelTemplate {
    NSString *indicatorType = panelTemplate.rootIndicatorType;
    NSDictionary *parameters = panelTemplate.rootIndicatorParams;

    if (!indicatorType || indicatorType.length == 0) {
        NSLog(@"⚠️ No root indicator type specified in template");
        return nil;
    }

    // ✅ MIGLIORATO: Usa deserializeFromDictionary se possibile
    if (parameters && parameters.count > 0) {
        // ✅ FIX: Extract lineWidth and displayColor from parameters and put them in main dict
        NSMutableDictionary *deserializeDict = [NSMutableDictionary dictionaryWithDictionary:@{
            @"class": indicatorType,
            @"parameters": parameters,
            @"isVisible": @YES
        }];

        // Extract lineWidth from parameters if present
        if (parameters[@"lineWidth"]) {
            deserializeDict[@"lineWidth"] = parameters[@"lineWidth"];
        }

        // Extract displayColor from parameters if present
        if (parameters[@"displayColor"]) {
            deserializeDict[@"displayColor"] = parameters[@"displayColor"];
        }

        // Extract color (legacy name) and map to displayColor
        if (parameters[@"color"] && !deserializeDict[@"displayColor"]) {
            deserializeDict[@"displayColor"] = parameters[@"color"];
        }

        TechnicalIndicatorBase *indicator = [TechnicalIndicatorBase deserializeFromDictionary:deserializeDict];
        if (indicator) {
            NSLog(@"✅ Created root indicator via deserialization: %@ (lineWidth=%.1f, color=%@)",
                  indicator.displayName, indicator.lineWidth, indicator.displayColor);
            return indicator;
        }
    }

    // ✅ FALLBACK: Manual creation
    Class indicatorClass = NSClassFromString(indicatorType);
    if (!indicatorClass || ![indicatorClass isSubclassOfClass:[TechnicalIndicatorBase class]]) {
        NSLog(@"❌ Invalid indicator class: %@", indicatorType);
        return nil;
    }

    TechnicalIndicatorBase *indicator = [[indicatorClass alloc] initWithParameters:parameters];


    NSLog(@"✅ Created root indicator manually: %@", indicator.displayName);
    return indicator;
}

- (TechnicalIndicatorBase *)createChildIndicatorFromDictionary:(NSDictionary *)childDict {
    NSLog(@"🔍 Creating child from dict: %@", childDict);

    // ✅ MIGLIORATO: Converte formato se necessario
    NSMutableDictionary *deserializeDict = [NSMutableDictionary dictionary];

    // Map fields to expected format
    NSString *className = childDict[@"class"];
    if (!className) {
        NSString *type = childDict[@"type"];
        if (type) {
            className = [NSString stringWithFormat:@"%@Indicator", type];
        }
    }

    if (!className) {
        NSLog(@"❌ No class or type found in child dict: %@", childDict);
        return nil;
    }

    deserializeDict[@"class"] = className;
    if (childDict[@"parameters"]) deserializeDict[@"parameters"] = childDict[@"parameters"];
    if (childDict[@"instanceID"]) deserializeDict[@"indicatorID"] = childDict[@"instanceID"];
    if (childDict[@"isVisible"]) deserializeDict[@"isVisible"] = childDict[@"isVisible"];

    // ✅ FIX: Extract lineWidth and displayColor from parameters if present
    NSDictionary *parameters = childDict[@"parameters"];
    if (parameters && [parameters isKindOfClass:[NSDictionary class]]) {
        if (parameters[@"lineWidth"]) {
            deserializeDict[@"lineWidth"] = parameters[@"lineWidth"];
        }
        if (parameters[@"displayColor"]) {
            deserializeDict[@"displayColor"] = parameters[@"displayColor"];
        }
        // Legacy color name mapping
        if (parameters[@"color"] && !deserializeDict[@"displayColor"]) {
            deserializeDict[@"displayColor"] = parameters[@"color"];
        }
    }

    // ✅ Use built-in deserialization
    TechnicalIndicatorBase *childIndicator = [TechnicalIndicatorBase deserializeFromDictionary:deserializeDict];

    if (!childIndicator) {
        NSLog(@"❌ Failed to deserialize child indicator from: %@", deserializeDict);
    } else {
        NSLog(@"✅ Created child indicator: %@ (lineWidth=%.1f, color=%@)",
              childIndicator.displayName, childIndicator.lineWidth, childIndicator.displayColor);
    }

    return childIndicator;
}



- (void)applyParametersManually:(NSDictionary *)parameters toIndicator:(TechnicalIndicatorBase *)indicator {
    // ✅ Common parameters mapping
    NSArray *parameterKeys = @[@"period", @"multiplier", @"kPeriod", @"dPeriod",
                              @"fastPeriod", @"slowPeriod", @"signalPeriod",
                              @"isVisible", @"color", @"lineWidth"];
    
    for (NSString *key in parameterKeys) {
        id value = parameters[key];
        if (value && ![value isKindOfClass:[NSNull class]]) {
            @try {
                [indicator setValue:value forKey:key];
                NSLog(@"📝 Set %@.%@ = %@", indicator.displayName, key, value);
            } @catch (NSException *exception) {
                // Key doesn't exist for this indicator - continue silently
            }
        }
    }
}

- (void)configureChildIndicators:(NSArray *)childIndicatorsData forRootIndicator:(TechnicalIndicatorBase *)rootIndicator {
    if (!childIndicatorsData || childIndicatorsData.count == 0) {
        return;
    }
    
    NSLog(@"👶 Configuring %ld child indicators for %@", childIndicatorsData.count, rootIndicator.displayName);
    
    NSMutableArray *childIndicators = [NSMutableArray array];
    
    for (id childData in childIndicatorsData) {
        if (![childData isKindOfClass:[NSDictionary class]]) {
            NSLog(@"⚠️ Invalid child indicator data: %@", childData);
            continue;
        }
        
        NSDictionary *childDict = (NSDictionary *)childData;
        TechnicalIndicatorBase *childIndicator = [self createChildIndicatorFromDictionary:childDict];
        
        if (childIndicator) {
            [childIndicators addObject:childIndicator];
            NSLog(@"✅ Created child indicator: %@", childIndicator.displayName);
        }
    }
    
    // ✅ Set child indicators on root
    if (childIndicators.count > 0) {
        rootIndicator.childIndicators = [childIndicators copy];
        NSLog(@"✅ Assigned %ld child indicators to %@", childIndicators.count, rootIndicator.displayName);
    }
}


#pragma mark - Period Optimization (NEW)

- (BOOL)isPeriodTooShortForIndicator:(TechnicalIndicatorBase *)indicator visibleRange:(NSInteger)visibleRange {
    // ⚠️ IMPORTANTE: Questo controllo si applica SOLO ai child indicators
    // Il root indicator (dati principali come prezzo) deve sempre essere disegnato
    BOOL isRootIndicator = (indicator == self.rootIndicator);
    if (isRootIndicator) {
        return NO; // Root indicator sempre disegnato
    }
    
    NSInteger period = [self extractPeriodFromIndicator:indicator];
    NSInteger threshold = period * 40;
    
    BOOL isTooShort = threshold < visibleRange;
    
    if (isTooShort) {
        NSLog(@"⚠️ Period too short: %@ (child) period=%ld, threshold=%ld, visibleRange=%ld",
              indicator.shortName, (long)period, (long)threshold, (long)visibleRange);
    }
    
    return isTooShort;
}

- (NSInteger)extractPeriodFromIndicator:(TechnicalIndicatorBase *)indicator {
    // Try to extract period from parameters
    id periodValue = indicator.parameters[@"period"];
    if (periodValue && [periodValue isKindOfClass:[NSNumber class]]) {
        return [periodValue integerValue];
    }
    
    // Fallback to minimumBarsRequired if period not found
    NSInteger minBars = indicator.minimumBarsRequired;
    return MAX(1, minBars);
}

#pragma mark - Warning Messages System (NEW)

- (void)addWarningMessage:(NSString *)message {
    if (![self.activeWarnings containsObject:message]) {
        [self.activeWarnings addObject:message];
        [self updateWarningMessagesDisplay];
        NSLog(@"⚠️ Added warning: %@", message);
    }
}

- (void)clearWarningMessages {
    [self.activeWarnings removeAllObjects];
    [self updateWarningMessagesDisplay];
}

- (void)updateWarningMessagesDisplay {
    if (self.activeWarnings.count == 0) {
        self.warningMessagesLayer.hidden = YES;
        self.warningMessagesLayer.string = @"";
        return;
    }
    
    // Join all warnings with newlines
    NSString *combinedWarnings = [self.activeWarnings componentsJoinedByString:@"\n"];
    self.warningMessagesLayer.string = combinedWarnings;
    self.warningMessagesLayer.hidden = NO;
    
    // Adjust layer height based on number of warnings
    CGRect currentFrame = self.warningMessagesLayer.frame;
    CGFloat newHeight = MAX(30, self.activeWarnings.count * 16 + 12); // 18px per line + padding
    self.warningMessagesLayer.frame = CGRectMake(currentFrame.origin.x,
                                               currentFrame.origin.y,
                                               currentFrame.size.width,
                                               newHeight);
    
    NSLog(@"📄 Updated warning display: %lu warnings", (unsigned long)self.activeWarnings.count);
}









#pragma mark - Rendering Management

- (void)renderIndicatorTree:(TechnicalIndicatorBase *)rootIndicator {
    self.rootIndicator = rootIndicator;
    
    if (!rootIndicator) {
        [self clearIndicatorLayers];
        return;
    }
    
    // Mark all indicators for rendering
    [self markAllIndicatorsForRerendering];
    
    // Trigger layer redraw
    [self invalidateIndicatorLayers];
    
    NSLog(@"🎨 Rendered indicator tree for: %@", rootIndicator.displayName);
}

- (void)clearIndicatorLayers {
    self.rootIndicator = nil;
    [self.indicatorsLayer setNeedsDisplay];
    
    NSLog(@"🧹 Cleared all indicator layers");
}

- (void)invalidateIndicatorLayers {
   
    [self.indicatorsLayer setNeedsDisplay];
}

#pragma mark - CALayerDelegate Implementation

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    if (layer != self.indicatorsLayer || !self.rootIndicator) {
        return;
    }
    
    // Setup NSGraphicsContext for NSBezierPath drawing
    NSGraphicsContext *nsContext = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:nsContext];
    
    // Verify coordinate contexts are available
    if (!self.panelView.sharedXContext || !self.panelView.panelYContext) {
        NSLog(@"⚠️ IndicatorRenderer: Missing coordinate contexts - skipping draw");
        [NSGraphicsContext restoreGraphicsState];
        return;
    }
    
    // Draw root indicator and children recursively
    [self drawIndicatorRecursively:self.rootIndicator];
    
    [NSGraphicsContext restoreGraphicsState];
    
    NSLog(@"🎨 Drew indicator tree in layer");
}

#pragma mark - Recursive Drawing

- (void)drawIndicatorRecursively:(TechnicalIndicatorBase *)indicator {
    if (!indicator || !indicator.isVisible || !indicator.outputSeries.count) {
        return;
    }
  
    
    BOOL isRoot = (indicator == self.rootIndicator);
     BOOL toggleIsOn = (self.panelView.chartWidget.indicatorsVisibilityToggle.state == NSControlStateValueOn);
     
    if (!isRoot && !toggleIsOn) {
         return;
     }
    // ✅ SKIP RENDERING FOR INDICATORS WITHOUT VISUAL OUTPUT
       if (![indicator hasVisualOutput]) {
           // Skip rendering ma continua con i children
           [self renderChildrenRecursively:indicator];
           return;
       }
       
       // 🆕 NEW: PERIOD OPTIMIZATION - Skip rendering if period too short
       NSInteger visibleRange = self.panelView.visibleEndIndex - self.panelView.visibleStartIndex + 1;
       if (visibleRange > 0 && [self isPeriodTooShortForIndicator:indicator visibleRange:visibleRange]) {
           
           // Add warning message
           NSString *warningMessage = [NSString stringWithFormat:@"⚠️ %@ periodi troppo brevi!", indicator.shortName];
           [self addWarningMessage:warningMessage];
           
           // Skip rendering completely for this indicator
           NSLog(@"🚫 Skipping render for %@ - period too short (range=%ld)",
                 indicator.shortName, (long)visibleRange);
           
           // Still process children (they might have different periods)
           [self renderChildrenRecursively:indicator];
           return;
       }
       
      
    // Draw this indicator based on its type
    switch (indicator.visualizationType) {
            case VisualizationTypeCandlestick:
                [self drawCandlestickIndicator:indicator];
                break;
                
            case VisualizationTypeHistogram:
                [self drawHistogramIndicator:indicator];
                break;
                
            case VisualizationTypeLine:
                [self drawLineIndicator:indicator];
                break;
                
            case VisualizationTypeArea:
                [self drawAreaIndicator:indicator];
                break;
                
            case VisualizationTypeOHLC:
                // TODO: Implementare OHLC bars se necessario
                [self drawLineIndicator:indicator]; // Fallback temporaneo
                break;
                
            default:
                // Fallback per tipi non gestiti
                [self drawLineIndicator:indicator];
                break;
        }
    
    // Recursively draw children
    [self renderChildrenRecursively:indicator];
}

- (void)renderChildrenRecursively:(TechnicalIndicatorBase *)parentIndicator {
    for (TechnicalIndicatorBase *child in parentIndicator.childIndicators) {
        [self drawIndicatorRecursively:child];
    }
}

#pragma mark - Visible Data Optimization (UPDATED)

- (BOOL)hasVisibleRangeChanged:(NSInteger)startIndex endIndex:(NSInteger)endIndex {
    return (self.panelView.visibleStartIndex != startIndex || self.panelView.visibleEndIndex != endIndex);
}

- (NSRange)validVisibleRangeForIndicator:(TechnicalIndicatorBase *)indicator
                              startIndex:(NSInteger)startIndex
                                endIndex:(NSInteger)endIndex {
    NSInteger dataCount = indicator.outputSeries.count;
    
    if (!dataCount || startIndex == NSNotFound || endIndex == NSNotFound) {
        return NSMakeRange(0, dataCount); // Return full range if no visible range specified
    }
    
    // ✅ VALIDAZIONE E CLAMPING DEGLI INDICI
    if (startIndex < 0) startIndex = 0;
    if (endIndex >= dataCount) endIndex = dataCount - 1;
    if (startIndex > endIndex) return NSMakeRange(0, 0); // Range invalido
    
    NSInteger length = endIndex - startIndex + 1; // +1 perché range è inclusivo
    return NSMakeRange(startIndex, length);
}

#pragma mark - Specialized Drawing Methods (UPDATED - No Array Allocation)

- (void)drawLineIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                   startIndex:self.panelView.visibleStartIndex
                                                     endIndex:self.panelView.visibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    NSBezierPath *path = [self createLinePathFromIndicator:indicator
                                                startIndex:visibleRange.location
                                                  endIndex:visibleRange.location + visibleRange.length - 1];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    [path stroke];

    NSLog(@"📈 Drew line indicator: %@ with range [%ld-%ld] (%ld points)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

- (void)drawHistogramIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                    startIndex:self.panelView.visibleStartIndex
                                                      endIndex:self.panelView.visibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    CGFloat barWidth = [self.panelView.sharedXContext barWidth] * 0.8;
    
    // ✅ NUOVO: Check se è un VolumeIndicator per rendering colorato
    BOOL isVolumeIndicator = [indicator isKindOfClass:NSClassFromString(@"VolumeIndicator")];
    
    if (isVolumeIndicator) {
        // ✅ NUOVO: Disegna barre colorate individualmente
        [self drawColoredHistogramBars:indicator visibleRange:visibleRange baselineY:baselineY barWidth:barWidth];
    } else {
        // ✅ ESISTENTE: Mantieni il rendering normale per altri indicatori
        [self drawStandardHistogramBars:indicator visibleRange:visibleRange baselineY:baselineY];
    }
    
    NSLog(@"📊 Drew %@ histogram indicator: %@ with range [%ld-%ld] (%ld bars)",
          isVolumeIndicator ? @"colored" : @"standard",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

// ✅ NUOVO: Metodo per disegnare barre colorate
- (void)drawColoredHistogramBars:(TechnicalIndicatorBase *)indicator
                    visibleRange:(NSRange)visibleRange
                       baselineY:(CGFloat)baselineY
                        barWidth:(CGFloat)barWidth {
    
    for (NSInteger i = visibleRange.location; i < visibleRange.location + visibleRange.length; i++) {
        IndicatorDataModel *dataPoint = indicator.outputSeries[i];
        
        if (isnan(dataPoint.value)) continue;
        
        CGFloat x = [self.panelView.sharedXContext screenXForBarIndex:i];
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        
        if (x < -9999 || y < -9999) continue;
        
        // ✅ NUOVO: Determina colore basato su priceDirection
        NSColor *barColor = [self colorForPriceDirection:dataPoint.priceDirection indicator:indicator];
        
        // Crea e disegna barra individuale
        CGFloat barHeight = ABS(y - baselineY);
        CGFloat barBottom = MIN(y, baselineY);
        NSRect barRect = NSMakeRect(x - barWidth/2, barBottom, barWidth, barHeight);
        
        [barColor setFill];
        NSBezierPath *barPath = [NSBezierPath bezierPathWithRect:barRect];
        [barPath fill];
        
        // Opzionale: Bordo sottile per definire meglio le barre
        [[NSColor colorWithWhite:0.0 alpha:0.1] setStroke];
        barPath.lineWidth = 0.5;
        [barPath stroke];
    }
}

// ✅ NUOVO: Metodo per disegnare barre standard (non colorate)
- (void)drawStandardHistogramBars:(TechnicalIndicatorBase *)indicator
                     visibleRange:(NSRange)visibleRange
                        baselineY:(CGFloat)baselineY {
    
    // Usa il metodo esistente createHistogramPathFromIndicator
    NSBezierPath *path = [self createHistogramPathFromIndicator:indicator
                                                     startIndex:visibleRange.location
                                                       endIndex:visibleRange.location + visibleRange.length - 1
                                                      baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
}

// ✅ NUOVO: Helper method per determinare colori
- (NSColor *)colorForPriceDirection:(PriceDirection)direction indicator:(TechnicalIndicatorBase *)indicator {
    switch (direction) {
        case PriceDirectionUp:
            return [NSColor systemGreenColor];    // Verde per up
        case PriceDirectionDown:
            return [NSColor systemRedColor];      // Rosso per down
        case PriceDirectionNeutral:
        default:
            return [NSColor systemGrayColor];     // Grigio per neutral/unknown
    }
}


- (void)drawAreaIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                    startIndex:self.panelView.visibleStartIndex
                                                      endIndex:self.panelView.visibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    CGFloat baselineY = [self yCoordinateForValue:0.0];
    NSBezierPath *path = [self createAreaPathFromIndicator:indicator
                                                startIndex:visibleRange.location
                                                  endIndex:visibleRange.location + visibleRange.length - 1
                                                 baselineY:baselineY];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    NSColor *fillColor = [[self defaultFillColorForIndicator:indicator] colorWithAlphaComponent:0.3];
    [fillColor setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎨 Drew area indicator: %@ with range [%ld-%ld] (%ld points)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

- (void)drawSignalIndicator:(TechnicalIndicatorBase *)indicator {
    if (!indicator.outputSeries.count) return;
    
    // ✅ USA GLI INDICI DIRETTAMENTE - NO ARRAY ALLOCATION
    NSRange visibleRange = [self validVisibleRangeForIndicator:indicator
                                                    startIndex:self.panelView.visibleStartIndex
                                                      endIndex:self.panelView.visibleEndIndex];
    
    if (visibleRange.length == 0) return;
    
    NSBezierPath *path = [self createSignalPathFromIndicator:indicator
                                                  startIndex:visibleRange.location
                                                    endIndex:visibleRange.location + visibleRange.length - 1];
    if (!path) return;
    
    // Apply style
    [self applyStyleToPath:path forIndicator:indicator];
    [[self defaultFillColorForIndicator:indicator] setFill];
    [[self defaultStrokeColorForIndicator:indicator] setStroke];
    
    // Draw
    [path fill];
    [path stroke];
    
    NSLog(@"🎯 Drew signal indicator: %@ with range [%ld-%ld] (%ld signals)",
          indicator.displayName, (long)visibleRange.location,
          (long)(visibleRange.location + visibleRange.length - 1), (long)visibleRange.length);
}

#pragma mark - BezierPath Creation Helpers (UPDATED - Direct Index Access)

// OPTIMIZED: Use sequential X coordinates (no per-point timestamp lookup), REVERSED iteration from endIndex to startIndex
- (NSBezierPath *)createLinePathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex {
    if (!indicator.outputSeries.count) return nil;
    if (!self.panelView.sharedXContext) return nil;
    NSBezierPath *path = [NSBezierPath bezierPath];
    BOOL isFirstPoint = YES;

    // Calcola X iniziale a partire da endIndex
    CGFloat x0 = [self.panelView.sharedXContext screenXForBarCenter:endIndex];
    CGFloat dx = [self.panelView.sharedXContext barWidth];
    CGFloat x = x0;
    // Itera da endIndex verso startIndex (inclusivo)
    for (NSInteger i = endIndex; i >= startIndex; i--) {
        IndicatorDataModel *dataPoint = indicator.outputSeries[i];
        if (isnan(dataPoint.value)) continue;
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        if (x < -9999 || y < -9999) { x -= dx; continue; }
        NSPoint point = NSMakePoint(x, y);
        if (isFirstPoint) {
            [path moveToPoint:point];
            isFirstPoint = NO;
        } else {
            [path lineToPoint:point];
        }
        x -= dx;
    }
    return path.elementCount > 0 ? path : nil;
}

// OPTIMIZED: Use sequential X coordinates (no per-point timestamp lookup)
- (NSBezierPath *)createHistogramPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                        startIndex:(NSInteger)startIndex
                                          endIndex:(NSInteger)endIndex
                                         baselineY:(CGFloat)baselineY {

    if (!indicator.outputSeries.count) return nil;
    if (!self.panelView.sharedXContext) return nil;

    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat barWidth = [self.panelView.sharedXContext barWidth] * 0.8;
    CGFloat x0 = [self.panelView.sharedXContext screenXForBarCenter:startIndex];
    CGFloat dx = [self.panelView.sharedXContext barWidth];
    CGFloat x = x0;

    for (NSInteger i = startIndex; i <= endIndex; i++) {
           IndicatorDataModel *dataPoint = indicator.outputSeries[i];
           if (isnan(dataPoint.value)) { x += dx; continue; }

           CGFloat y = [self yCoordinateForValue:dataPoint.value];
           if (x < -9999 || y < -9999) { x += dx; continue; }

           if (barWidth <= SIMPLIFIED_DRAWING_THRESHOLD) { // ✅ USA COSTANTE UNIFICATA
               // Draw a simple vertical line
               [path moveToPoint:NSMakePoint(x, baselineY)];
               [path lineToPoint:NSMakePoint(x, y)];
           } else {
               // Draw full rectangle
               CGFloat barHeight = ABS(y - baselineY);
               CGFloat barBottom = MIN(y, baselineY);
               NSRect barRect = NSMakeRect(x - barWidth/2, barBottom, barWidth, barHeight);
               [path appendBezierPathWithRect:barRect];
           }

           x += dx;
       }

       return path.elementCount > 0 ? path : nil;
}

// OPTIMIZED: Use sequential X coordinates (no per-point timestamp lookup)
- (NSBezierPath *)createAreaPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                   startIndex:(NSInteger)startIndex
                                     endIndex:(NSInteger)endIndex
                                    baselineY:(CGFloat)baselineY {
    if (!indicator.outputSeries.count) return nil;
    if (!self.panelView.sharedXContext) return nil;
    NSBezierPath *path = [NSBezierPath bezierPath];
    NSMutableArray *validPoints = [NSMutableArray array];
    CGFloat x0 = [self.panelView.sharedXContext screenXForBarCenter:startIndex];
    CGFloat dx = [self.panelView.sharedXContext barWidth];
    CGFloat x = x0;
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = indicator.outputSeries[i];
        if (isnan(dataPoint.value)) { x += dx; continue; }
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        if (x > -9999 && y > -9999) {
            [validPoints addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
        }
        x += dx;
    }
    if (!validPoints.count) return nil;
    NSPoint firstPoint = [[validPoints firstObject] pointValue];
    [path moveToPoint:NSMakePoint(firstPoint.x, baselineY)];
    for (NSValue *pointValue in validPoints) {
        [path lineToPoint:[pointValue pointValue]];
    }
    NSPoint lastPoint = [[validPoints lastObject] pointValue];
    [path lineToPoint:NSMakePoint(lastPoint.x, baselineY)];
    [path closePath];
    return path;
}

// OPTIMIZED: Use sequential X coordinates (no per-point timestamp lookup)
- (NSBezierPath *)createSignalPathFromIndicator:(TechnicalIndicatorBase *)indicator
                                     startIndex:(NSInteger)startIndex
                                       endIndex:(NSInteger)endIndex {
    if (!indicator.outputSeries.count) return nil;
    if (!self.panelView.sharedXContext) return nil;
    NSBezierPath *path = [NSBezierPath bezierPath];
    CGFloat markerSize = 6.0;
    CGFloat x0 = [self.panelView.sharedXContext screenXForBarCenter:startIndex];
    CGFloat dx = [self.panelView.sharedXContext barWidth];
    CGFloat x = x0;
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        IndicatorDataModel *dataPoint = indicator.outputSeries[i];
        if (ABS(dataPoint.value) < 0.001) { x += dx; continue; }
        CGFloat y = [self yCoordinateForValue:dataPoint.value];
        if (x < -9999 || y < -9999) { x += dx; continue; }
        NSRect markerRect = NSMakeRect(x - markerSize/2, y - markerSize/2, markerSize, markerSize);
        [path appendBezierPathWithOvalInRect:markerRect];
        x += dx;
    }
    return path.elementCount > 0 ? path : nil;
}


- (void)drawBandsIndicator:(TechnicalIndicatorBase *)indicator {
    // For bands, we expect multiple series (upper, middle, lower)
    // This is a simplified implementation - might need adjustment based on actual data structure
    
    [self drawLineIndicator:indicator]; // Fallback to line for now
    
    NSLog(@"📏 Drew bands indicator: %@", indicator.displayName);
}


#pragma mark - Specialized Drawing Methods

- (void)drawCandlestickIndicator:(TechnicalIndicatorBase *)indicator {
    // Per i candlestick, abbiamo bisogno dei dati OHLC originali dal ChartPanelView
    NSArray<HistoricalBarModel *> *chartData = self.panelView.chartData;
    if (!chartData.count) {
        NSLog(@"⚠️ No chart data available for candlestick rendering");
        return;
    }
    
    NSInteger startIndex = self.panelView.visibleStartIndex;
    NSInteger endIndex = self.panelView.visibleEndIndex;
    
    // Verifica range valido
    if (startIndex == NSNotFound || endIndex == NSNotFound || startIndex > endIndex) {
        NSLog(@"⚠️ Invalid visible range for candlestick rendering");
        return;
    }
    
    // Verifica che i coordinate contexts siano disponibili
    if (!self.panelView.sharedXContext || !self.panelView.panelYContext) {
        NSLog(@"⚠️ Missing coordinate contexts for candlestick rendering");
        return;
    }
    
    // ✅ Calcola barWidth per ottimizzazione
    CGFloat barWidth = [self.panelView.sharedXContext barWidth];
    barWidth -= [self.panelView.sharedXContext barSpacing];
    
    // 🚀 OTTIMIZZAZIONE: Se barWidth <= 1px, disegna solo linee semplici
    if (barWidth <= SIMPLIFIED_DRAWING_THRESHOLD) {
        [self drawSimplifiedCandlesticks:chartData startIndex:startIndex endIndex:endIndex];
        return;
    }
    
    // ✅ DISEGNO COMPLETO per barWidth > 1px
    [self drawFullCandlesticks:chartData startIndex:startIndex endIndex:endIndex barWidth:barWidth];
    
    NSLog(@"🕯️ Drew candlestick indicator with %ld bars (width: %.1fpx)",
          (long)(endIndex - startIndex + 1), barWidth);
}

// 🚀 METODO PRIVATO: Disegno semplificato quando width <= 1px
- (void)drawSimplifiedCandlesticks:(NSArray<HistoricalBarModel *> *)chartData
                        startIndex:(NSInteger)startIndex
                          endIndex:(NSInteger)endIndex {
    
    NSColor *neutralColor = SIMPLIFIED_DRAWING_COLOR ; // Colore neutro standard

    NSBezierPath *simplePath = [NSBezierPath bezierPath];
    simplePath.lineWidth = 1.0;
    
    [neutralColor setStroke];
    
    for (NSInteger i = startIndex; i <= endIndex && i < chartData.count; i++) {
        HistoricalBarModel *bar = chartData[i];
        
        // ✅ COORDINATE X - dal sharedXContext
        CGFloat centerX = [self.panelView.sharedXContext screenXForBarCenter:i];

        // ✅ COORDINATE Y - dal panelYContext
        CGFloat highY = [self.panelView.panelYContext screenYForValue:bar.high];
        CGFloat lowY = [self.panelView.panelYContext screenYForValue:bar.low];
        
        // Disegna solo una linea verticale da high a low
        [simplePath moveToPoint:NSMakePoint(centerX, highY)];
        [simplePath lineToPoint:NSMakePoint(centerX, lowY)];
    }
    
    [simplePath stroke];
    NSLog(@"📊 Simplified candlesticks drawn (%ld bars, width <= 1px)", (long)(endIndex - startIndex + 1));
}

// ✅ METODO PRIVATO: Disegno completo per barWidth > 1px
- (void)drawFullCandlesticks:(NSArray<HistoricalBarModel *> *)chartData
                  startIndex:(NSInteger)startIndex
                    endIndex:(NSInteger)endIndex
                    barWidth:(CGFloat)barWidth {
    
    // ✅ Pre-alloca colori e paths
    NSColor *greenColor = [NSColor systemGreenColor];
    NSColor *redColor = [NSColor systemRedColor];
    NSColor *strokeColor = [NSColor labelColor];
    CGFloat halfBarWidth = barWidth / 2.0;
    
    NSBezierPath *shadowPath = [NSBezierPath bezierPath];
    NSBezierPath *bodyPath = [NSBezierPath bezierPath];
    shadowPath.lineWidth = 1.0;
    
    for (NSInteger i = startIndex; i <= endIndex && i < chartData.count; i++) {
        HistoricalBarModel *bar = chartData[i];
        
        // ✅ COORDINATE X - dal sharedXContext
        CGFloat centerX = [self.panelView.sharedXContext screenXForBarCenter:i];
        CGFloat x = centerX - halfBarWidth;
        
        
        // ✅ COORDINATE Y - dal panelYContext
        CGFloat openY = [self.panelView.panelYContext screenYForValue:bar.open];
        CGFloat closeY = [self.panelView.panelYContext screenYForValue:bar.close];
        CGFloat highY = [self.panelView.panelYContext screenYForValue:bar.high];
        CGFloat lowY = [self.panelView.panelYContext screenYForValue:bar.low];
        
        NSColor *bodyColor = (bar.close >= bar.open) ? greenColor : redColor;
        
        // ✅ Draw high-low line (wick)
        [strokeColor setStroke];
        [shadowPath removeAllPoints];
        [shadowPath moveToPoint:NSMakePoint(centerX, highY)];
        [shadowPath lineToPoint:NSMakePoint(centerX, lowY)];
        [shadowPath stroke];
        
        // ✅ Draw body rectangle
        CGFloat bodyTop = MAX(openY, closeY);
        CGFloat bodyBottom = MIN(openY, closeY);
        CGFloat bodyHeight = bodyTop - bodyBottom;
        
        if (bodyHeight < 1) bodyHeight = 1; // Minimum height for doji
        
        NSRect bodyRect = NSMakeRect(x, bodyBottom, barWidth, bodyHeight);
        [bodyColor setFill];
        [bodyPath removeAllPoints];
        [bodyPath appendBezierPathWithRect:bodyRect];
        [bodyPath fill];
    }
    
    NSLog(@"📊 Full candlesticks drawn (%ld bars, width > 1px)", (long)(endIndex - startIndex + 1));
}

#pragma mark - Coordinate Conversion

- (CGFloat)xCoordinateForTimestamp:(NSDate *)timestamp {
    if (!self.panelView.sharedXContext || !timestamp) {
        return -9999;
    }
    
    return [self.panelView.sharedXContext screenXForDate:timestamp];
}

- (CGFloat)yCoordinateForValue:(double)value {
    if (!self.panelView.panelYContext) {
        return -9999;
    }
    
    return [self.panelView.panelYContext screenYForValue:value];
}

#pragma mark - Style and Color Helpers

- (NSColor *)defaultStrokeColorForIndicator:(TechnicalIndicatorBase *)indicator {
    NSColor *displayColor = nil;
    
    // ✅ STRATEGY 1: Prova displayColor property
    if ([indicator respondsToSelector:@selector(displayColor)]) {
        displayColor = indicator.displayColor;
    }
    
    // ✅ STRATEGY 2: Cerca nei parametri
    if (!displayColor && indicator.parameters) {
        displayColor = indicator.parameters[@"color"] ?: indicator.parameters[@"displayColor"];
    }
    
    // ✅ STRATEGY 3: Default sicuro
    if (!displayColor) {
        displayColor = [NSColor systemBlueColor];
    }
    
    NSLog(@"🎨 defaultStrokeColorForIndicator %@: %@",
          indicator.shortName ?: @"Unknown", displayColor);
    
    return displayColor;
}
- (CGFloat)defaultLineWidthForIndicator:(TechnicalIndicatorBase *)indicator {
    // Return indicator-specific width or default
    return indicator.lineWidth > 0 ? indicator.lineWidth : 2.0;
}

- (NSColor *)defaultFillColorForIndicator:(TechnicalIndicatorBase *)indicator {
    // Return indicator-specific fill color or derive from stroke color
    return indicator.displayColor ?: [self defaultStrokeColorForIndicator:indicator];
}

- (void)applyStyleToPath:(NSBezierPath *)path forIndicator:(TechnicalIndicatorBase *)indicator {
    path.lineWidth = [self defaultLineWidthForIndicator:indicator];
    path.lineCapStyle = NSLineCapStyleRound;
    path.lineJoinStyle = NSLineJoinStyleRound;
    
    // Apply dash pattern if needed
    if ([indicator respondsToSelector:@selector(isDashed)] &&
        [[indicator valueForKey:@"isDashed"] boolValue]) {
        CGFloat pattern[] = {5.0, 3.0};
        [path setLineDash:pattern count:2 phase:0];
    }
}

#pragma mark - Visible Data Optimization



#pragma mark - Visibility Management

- (void)setVisibilityRecursively:(NSArray<TechnicalIndicatorBase *> *)indicators visible:(BOOL)visible {
    for (TechnicalIndicatorBase *indicator in indicators) {
        if (indicator != self.rootIndicator) {
            indicator.isVisible = visible;
            indicator.needsRendering = YES;
        }
       
        
        // Recursively apply to children
        if (indicator.childIndicators.count > 0) {
            [self setVisibilityRecursively:indicator.childIndicators visible:visible];
        }
    }
}

- (void)markAllIndicatorsForRerendering {
    if (self.rootIndicator) {
        [self markIndicatorForRerenderingRecursively:self.rootIndicator];
    }
}

- (void)markIndicatorForRerenderingRecursively:(TechnicalIndicatorBase *)indicator {
    indicator.needsRendering = YES;
    
    for (TechnicalIndicatorBase *child in indicator.childIndicators) {
        [self markIndicatorForRerenderingRecursively:child];
    }
}

#pragma mark - Cleanup

- (void)cleanup {
    [self clearIndicatorLayers];
    
    if (self.indicatorsLayer) {
        [self.indicatorsLayer removeFromSuperlayer];
        self.indicatorsLayer.delegate = nil;
        self.indicatorsLayer = nil;
    }
    
    if (self.warningMessagesLayer) {
          [self.warningMessagesLayer removeFromSuperlayer];
          self.warningMessagesLayer = nil;
      }
    
    self.panelView = nil;
    
    NSLog(@"🧹 ChartIndicatorRenderer: Cleanup completed");
}


#pragma mark - Data Calculation (NEW)

- (void)recalculateIndicatorsWithData:(NSArray<HistoricalBarModel *> *)chartData {
    if (!self.rootIndicator || !chartData || chartData.count == 0) {
        NSLog(@"⚠️ IndicatorRenderer: Cannot recalculate - missing rootIndicator or chartData");
        return;
    }
    
    NSLog(@"🔄 Recalculating indicators with %ld bars", chartData.count);
    
    // Calculate root indicator
    [self.rootIndicator calculateWithBars:chartData];
    
    // Calculate children recursively
    [self recalculateChildrenForIndicator:self.rootIndicator withData:chartData];
    
    // Trigger redraw
    [self invalidateIndicatorLayers];
}

- (void)recalculateChildrenForIndicator:(TechnicalIndicatorBase *)indicator withData:(NSArray<HistoricalBarModel *> *)chartData {
    for (TechnicalIndicatorBase *child in indicator.childIndicators) {
        [child calculateWithBars:chartData];
        [self recalculateChildrenForIndicator:child withData:chartData];
    }
}

@end
