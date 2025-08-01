//
//  ConnectionTypes.m
//  mafia_AI
//

#import "ConnectionTypes.h"
#import <Cocoa/Cocoa.h>

#pragma mark - Connection Type Utilities

NSString *StringFromConnectionType(StockConnectionType type) {
    switch (type) {
        case StockConnectionTypeNews:
            return @"News";
        case StockConnectionTypePersonalNote:
            return @"Personal Note";
        case StockConnectionTypeSympathy:
            return @"Sympathy Move";
        case StockConnectionTypeCollaboration:
            return @"Collaboration";
        case StockConnectionTypeMerger:
            return @"Merger/Acquisition";
        case StockConnectionTypePartnership:
            return @"Partnership";
        case StockConnectionTypeSupplier:
            return @"Supplier Relationship";
        case StockConnectionTypeCompetitor:
            return @"Competitor";
        case StockConnectionTypeCorrelation:
            return @"Correlation";
        case StockConnectionTypeSector:
            return @"Same Sector";
        case StockConnectionTypeCustom:
            return @"Custom";
        default:
            return @"Unknown";
    }
}

StockConnectionType ConnectionTypeFromString(NSString *string) {
    if ([string isEqualToString:@"News"]) return StockConnectionTypeNews;
    if ([string isEqualToString:@"Personal Note"]) return StockConnectionTypePersonalNote;
    if ([string isEqualToString:@"Sympathy Move"]) return StockConnectionTypeSympathy;
    if ([string isEqualToString:@"Collaboration"]) return StockConnectionTypeCollaboration;
    if ([string isEqualToString:@"Merger/Acquisition"]) return StockConnectionTypeMerger;
    if ([string isEqualToString:@"Partnership"]) return StockConnectionTypePartnership;
    if ([string isEqualToString:@"Supplier Relationship"]) return StockConnectionTypeSupplier;
    if ([string isEqualToString:@"Competitor"]) return StockConnectionTypeCompetitor;
    if ([string isEqualToString:@"Correlation"]) return StockConnectionTypeCorrelation;
    if ([string isEqualToString:@"Same Sector"]) return StockConnectionTypeSector;
    if ([string isEqualToString:@"Custom"]) return StockConnectionTypeCustom;
    return StockConnectionTypeNews; // Default
}

#pragma mark - Summary Source Utilities

NSString *StringFromSummarySource(ConnectionSummarySource source) {
    switch (source) {
        case ConnectionSummarySourceNone:
            return @"None";
        case ConnectionSummarySourceAI:
            return @"AI Generated";
        case ConnectionSummarySourceManual:
            return @"Manual";
        case ConnectionSummarySourceBoth:
            return @"AI + Manual";
        default:
            return @"None";
    }
}

ConnectionSummarySource SummarySourceFromString(NSString *string) {
    if ([string isEqualToString:@"AI Generated"]) return ConnectionSummarySourceAI;
    if ([string isEqualToString:@"Manual"]) return ConnectionSummarySourceManual;
    if ([string isEqualToString:@"AI + Manual"]) return ConnectionSummarySourceBoth;
    return ConnectionSummarySourceNone;
}

#pragma mark - Decay Type Utilities

NSString *StringFromDecayType(ConnectionDecayType type) {
    switch (type) {
        case ConnectionDecayTypeNone:
            return @"No Decay";
        case ConnectionDecayTypeLinear:
            return @"Linear";
        case ConnectionDecayTypeExponential:
            return @"Exponential";
        case ConnectionDecayTypeStep:
            return @"Step";
        default:
            return @"No Decay";
    }
}

ConnectionDecayType DecayTypeFromString(NSString *string) {
    if ([string isEqualToString:@"Linear"]) return ConnectionDecayTypeLinear;
    if ([string isEqualToString:@"Exponential"]) return ConnectionDecayTypeExponential;
    if ([string isEqualToString:@"Step"]) return ConnectionDecayTypeStep;
    return ConnectionDecayTypeNone;
}

#pragma mark - Visual Utilities

NSString *IconForConnectionType(StockConnectionType type) {
    switch (type) {
        case StockConnectionTypeNews:
            return @"newspaper";
        case StockConnectionTypePersonalNote:
            return @"note.text";
        case StockConnectionTypeSympathy:
            return @"arrow.up.arrow.down";
        case StockConnectionTypeCollaboration:
            return @"handshake";
        case StockConnectionTypeMerger:
            return @"arrow.triangle.merge";
        case StockConnectionTypePartnership:
            return @"person.2";
        case StockConnectionTypeSupplier:
            return @"shippingbox";
        case StockConnectionTypeCompetitor:
            return @"flame";
        case StockConnectionTypeCorrelation:
            return @"chart.line.uptrend.xyaxis";
        case StockConnectionTypeSector:
            return @"building.2";
        case StockConnectionTypeCustom:
            return @"star";
        default:
            return @"link";
    }
}

NSColor *ColorForConnectionType(StockConnectionType type) {
    switch (type) {
        case StockConnectionTypeNews:
            return [NSColor systemBlueColor];
        case StockConnectionTypePersonalNote:
            return [NSColor systemGrayColor];
        case StockConnectionTypeSympathy:
            return [NSColor systemOrangeColor];
        case StockConnectionTypeCollaboration:
            return [NSColor systemGreenColor];
        case StockConnectionTypeMerger:
            return [NSColor systemPurpleColor];
        case StockConnectionTypePartnership:
            return [NSColor systemTealColor];
        case StockConnectionTypeSupplier:
            return [NSColor systemBrownColor];
        case StockConnectionTypeCompetitor:
            return [NSColor systemRedColor];
        case StockConnectionTypeCorrelation:
            return [NSColor systemYellowColor];
        case StockConnectionTypeSector:
            return [NSColor systemIndigoColor];
        case StockConnectionTypeCustom:
            return [NSColor systemPinkColor];
        default:
            return [NSColor labelColor];
    }
}
