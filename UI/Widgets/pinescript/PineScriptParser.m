
//
//  PineScriptParser.m
//  TradingApp
//

#import "PineScriptParser.h"

#pragma mark - AST Node Implementations

@implementation PineScriptFunction
@end

@implementation PineScriptVariable
@end

@implementation PineScriptExpression
@end

@implementation PineScriptParseResult

- (instancetype)init {
    self = [super init];
    if (self) {
        _success = NO;
        _errorLine = -1;
        _errorColumn = -1;
        _warnings = @[];
        _inputs = @[];
        _variables = @[];
        _plots = @[];
        _functions = @[];
        _expressions = @[];
        _requiredBars = @[];
        _isOverlay = NO;
    }
    return self;
}

@end

#pragma mark - PineScript Parser Implementation

@implementation PineScriptParser

#pragma mark - Parsing

+ (PineScriptParseResult *)parseScript:(NSString *)script {
    PineScriptParseResult *result = [[PineScriptParseResult alloc] init];
    
    if (!script.length) {
        result.errorMessage = @"Empty script";
        return result;
    }
    
    NSArray *lines = [script componentsSeparatedByString:@"\n"];
    NSMutableArray *warnings = [NSMutableArray array];
    NSMutableArray *inputs = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    NSMutableArray *plots = [NSMutableArray array];
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *expressions = [NSMutableArray array];
    
    NSInteger lineNumber = 0;
    BOOL hasStudyDeclaration = NO;
    
    for (NSString *line in lines) {
        lineNumber++;
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // Skip empty lines and comments
        if (trimmedLine.length == 0 || [trimmedLine hasPrefix:@"//"]) {
            continue;
        }
        
        // Parse study declaration
        if ([trimmedLine hasPrefix:@"study("]) {
            PineScriptFunction *study = [self parseStudyDeclaration:trimmedLine lineNumber:lineNumber];
            if (study) {
                result.studyDeclaration = study;
                result.indicatorName = study.metadata[@"title"];
                result.shortTitle = study.metadata[@"shorttitle"];
                result.isOverlay = [study.metadata[@"overlay"] boolValue];
                hasStudyDeclaration = YES;
            } else {
                result.errorMessage = @"Invalid study declaration";
                result.errorLine = lineNumber;
                return result;
            }
        }
        // Parse input declarations
        else if ([self lineContainsInputDeclaration:trimmedLine]) {
            PineScriptVariable *input = [self parseInputDeclaration:trimmedLine lineNumber:lineNumber];
            if (input) {
                [inputs addObject:input];
            } else {
                [warnings addObject:[NSString stringWithFormat:@"Line %ld: Invalid input declaration", lineNumber]];
            }
        }
        // Parse plot functions
        else if ([trimmedLine hasPrefix:@"plot("]) {
            PineScriptFunction *plot = [self parsePlotFunction:trimmedLine lineNumber:lineNumber];
            if (plot) {
                [plots addObject:plot];
            } else {
                [warnings addObject:[NSString stringWithFormat:@"Line %ld: Invalid plot function", lineNumber]];
            }
        }
        // Parse variable assignments
        else if ([self lineContainsVariableAssignment:trimmedLine]) {
            PineScriptVariable *variable = [self parseVariableAssignment:trimmedLine lineNumber:lineNumber];
            if (variable) {
                [variables addObject:variable];
            }
        }
        // Parse expressions
        else {
            PineScriptExpression *expression = [self parseExpression:trimmedLine lineNumber:lineNumber];
            if (expression) {
                [expressions addObject:expression];
            }
        }
    }
    
    // Validation
    if (!hasStudyDeclaration) {
        [warnings addObject:@"No study() declaration found"];
    }
    
    if (plots.count == 0) {
        [warnings addObject:@"No plot() functions found - indicator will not produce visible output"];
    }
    
    // Success
    result.success = YES;
    result.warnings = [warnings copy];
    result.inputs = [inputs copy];
    result.variables = [variables copy];
    result.plots = [plots copy];
    result.functions = [functions copy];
    result.expressions = [expressions copy];
    
    return result;
}

+ (PineScriptParseResult *)validateParsedScript:(PineScriptParseResult *)parseResult {
    if (!parseResult.success) {
        return parseResult;
    }
    
    NSMutableArray *warnings = [parseResult.warnings mutableCopy];
    
    // Check for unused inputs
    NSMutableSet *usedInputs = [NSMutableSet set];
    for (PineScriptExpression *expr in parseResult.expressions) {
        for (PineScriptVariable *input in parseResult.inputs) {
            if ([expr.expression containsString:input.name]) {
                [usedInputs addObject:input.name];
            }
        }
    }
    
    for (PineScriptVariable *input in parseResult.inputs) {
        if (![usedInputs containsObject:input.name]) {
            [warnings addObject:[NSString stringWithFormat:@"Input '%@' is declared but never used", input.name]];
        }
    }
    
    // Check for performance issues
    for (PineScriptExpression *expr in parseResult.expressions) {
        if ([expr.expression containsString:@"for "] && [expr.expression containsString:@"for "]) {
            [warnings addObject:[NSString stringWithFormat:@"Line %ld: Nested loops detected - may impact performance", expr.lineNumber]];
        }
    }
    
    parseResult.warnings = [warnings copy];
    return parseResult;
}

#pragma mark - Parsing Helpers

+ (PineScriptFunction *)parseStudyDeclaration:(NSString *)line lineNumber:(NSInteger)lineNumber {
    // Parse: study("Title", shorttitle="ST", overlay=true)
    PineScriptFunction *study = [[PineScriptFunction alloc] init];
    study.name = @"study";
    study.lineNumber = lineNumber;
    
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    // Extract title
    NSRegularExpression *titleRegex = [NSRegularExpression regularExpressionWithPattern:@"study\\s*\\(\\s*\"([^\"]+)\"" options:0 error:nil];
    NSTextCheckingResult *titleMatch = [titleRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (titleMatch && titleMatch.numberOfRanges > 1) {
        metadata[@"title"] = [line substringWithRange:[titleMatch rangeAtIndex:1]];
    }
    
    // Extract shorttitle
    NSRegularExpression *shortRegex = [NSRegularExpression regularExpressionWithPattern:@"shorttitle\\s*=\\s*\"([^\"]+)\"" options:0 error:nil];
    NSTextCheckingResult *shortMatch = [shortRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (shortMatch && shortMatch.numberOfRanges > 1) {
        metadata[@"shorttitle"] = [line substringWithRange:[shortMatch rangeAtIndex:1]];
    }
    
    // Extract overlay
    if ([line containsString:@"overlay=true"]) {
        metadata[@"overlay"] = @YES;
    } else if ([line containsString:@"overlay=false"]) {
        metadata[@"overlay"] = @NO;
    }
    
    study.metadata = [metadata copy];
    return study;
}

+ (BOOL)lineContainsInputDeclaration:(NSString *)line {
    return [line containsString:@"input("] || [line containsString:@"= input("];
}

+ (PineScriptVariable *)parseInputDeclaration:(NSString *)line lineNumber:(NSInteger)lineNumber {
    // Parse: length = input(20, "Length") or input.int(20, "Length")
    PineScriptVariable *input = [[PineScriptVariable alloc] init];
    input.lineNumber = lineNumber;
    
    // Extract variable name
    NSRange equalRange = [line rangeOfString:@"="];
    if (equalRange.location != NSNotFound) {
        NSString *varName = [[line substringToIndex:equalRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        input.name = varName;
    }
    
    // Extract default value
    NSRegularExpression *valueRegex = [NSRegularExpression regularExpressionWithPattern:@"input\\s*\\(\\s*([^,)]+)" options:0 error:nil];
    NSTextCheckingResult *valueMatch = [valueRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (valueMatch && valueMatch.numberOfRanges > 1) {
        NSString *valueStr = [line substringWithRange:[valueMatch rangeAtIndex:1]];
        input.value = [self parseValue:valueStr];
        input.type = [self inferTypeFromValue:input.value];
    }
    
    return input;
}

+ (PineScriptFunction *)parsePlotFunction:(NSString *)line lineNumber:(NSInteger)lineNumber {
    // Parse: plot(sma_value, "SMA", color=color.blue)
    PineScriptFunction *plot = [[PineScriptFunction alloc] init];
    plot.name = @"plot";
    plot.lineNumber = lineNumber;
    
    // Extract parameters
    NSRegularExpression *paramsRegex = [NSRegularExpression regularExpressionWithPattern:@"plot\\s*\\(([^)]+)\\)" options:0 error:nil];
    NSTextCheckingResult *paramsMatch = [paramsRegex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
    if (paramsMatch && paramsMatch.numberOfRanges > 1) {
        NSString *paramsStr = [line substringWithRange:[paramsMatch rangeAtIndex:1]];
        NSArray *params = [paramsStr componentsSeparatedByString:@","];
        NSMutableArray *cleanParams = [NSMutableArray array];
        
        for (NSString *param in params) {
            [cleanParams addObject:[param stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        }
        
        plot.parameters = [cleanParams copy];
    }
    
    return plot;
}

+ (BOOL)lineContainsVariableAssignment:(NSString *)line {
    return [line containsString:@"="] && ![line containsString:@"=="] && ![line containsString:@"!="] && ![line containsString:@"<="] && ![line containsString:@">="];
}

+ (PineScriptVariable *)parseVariableAssignment:(NSString *)line lineNumber:(NSInteger)lineNumber {
    // Parse: sma_value = sma(close, length)
    PineScriptVariable *variable = [[PineScriptVariable alloc] init];
    variable.lineNumber = lineNumber;
    
    NSRange equalRange = [line rangeOfString:@"="];
    if (equalRange.location != NSNotFound) {
        variable.name = [[line substringToIndex:equalRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        variable.value = [[line substringFromIndex:equalRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        variable.type = @"expression";
    }
    
    return variable;
}

+ (PineScriptExpression *)parseExpression:(NSString *)line lineNumber:(NSInteger)lineNumber {
    PineScriptExpression *expression = [[PineScriptExpression alloc] init];
    expression.expression = line;
    expression.lineNumber = lineNumber;
    expression.resultType = @"unknown";
    
    return expression;
}

+ (id)parseValue:(NSString *)valueStr {
    valueStr = [valueStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    // Try to parse as number
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSNumber *number = [formatter numberFromString:valueStr];
    if (number) {
        return number;
    }
    
    // Check for boolean
    if ([valueStr isEqualToString:@"true"]) return @YES;
    if ([valueStr isEqualToString:@"false"]) return @NO;
    
    // Check for string (remove quotes)
    if ([valueStr hasPrefix:@"\""] && [valueStr hasSuffix:@"\""]) {
        return [valueStr substringWithRange:NSMakeRange(1, valueStr.length - 2)];
    }
    
    // Return as string
    return valueStr;
}

+ (NSString *)inferTypeFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        return @"number";
    } else if ([value isKindOfClass:[NSString class]]) {
        return @"string";
    }
    return @"unknown";
}

#pragma mark - Built-in Functions and Constants

+ (NSArray<NSString *> *)supportedBuiltinFunctions {
    return @[
        // Math functions
        @"sma", @"ema", @"rsi", @"atr", @"stdev", @"abs", @"max", @"min", @"round", @"floor", @"ceil",
        
        // Price functions
        @"open", @"high", @"low", @"close", @"volume", @"hl2", @"hlc3", @"ohlc4",
        
        // Technical analysis
        @"sma", @"ema", @"wma", @"rma", @"rsi", @"macd", @"bbands", @"atr", @"adx",
        
        // Math operators
        @"cross", @"crossover", @"crossunder", @"rising", @"falling",
        
        // Conditional
        @"if", @"iff", @"na",
        
        // Drawing
        @"plot", @"hline", @"fill", @"bgcolor", @"plotshape",
        
        // Input
        @"input", @"input.int", @"input.float", @"input.bool", @"input.string"
    ];
}

+ (NSArray<NSString *> *)supportedConstants {
    return @[
        @"open", @"high", @"low", @"close", @"volume",
        @"true", @"false", @"na",
        @"color.red", @"color.green", @"color.blue", @"color.yellow", @"color.orange", @"color.purple", @"color.white", @"color.black"
    ];
}

+ (NSArray<NSString *> *)supportedInputTypes {
    return @[@"int", @"float", @"bool", @"string", @"color"];
}

+ (BOOL)isBuiltinFunction:(NSString *)functionName {
    return [[self supportedBuiltinFunctions] containsObject:functionName];
}

+ (NSDictionary *)signatureForBuiltinFunction:(NSString *)functionName {
    static NSDictionary *signatures = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        signatures = @{
            @"sma": @{@"params": @[@"source", @"length"], @"returns": @"number"},
            @"ema": @{@"params": @[@"source", @"length"], @"returns": @"number"},
            @"rsi": @{@"params": @[@"source", @"length"], @"returns": @"number"},
            @"atr": @{@"params": @[@"length"], @"returns": @"number"},
            @"plot": @{@"params": @[@"series", @"title", @"color"], @"returns": @"void"},
            @"input": @{@"params": @[@"default", @"title"], @"returns": @"any"},
            @"hline": @{@"params": @[@"price", @"title", @"color"], @"returns": @"void"}
        };
    });
    
    return signatures[functionName];
}

#pragma mark - Code Generation

+ (NSString *)generateObjectiveCIndicatorFromParseResult:(PineScriptParseResult *)parseResult className:(NSString *)className {
    if (!parseResult.success) {
        return nil;
    }
    
    NSMutableString *code = [NSMutableString string];
    
    // Header
    [code appendFormat:@"//\n// %@.m\n// Generated from PineScript\n//\n\n", className];
    [code appendString:@"#import \"TechnicalIndicatorBase.h\"\n#import \"IndicatorDataModel.h\"\n\n"];
    
    // Interface
    [code appendFormat:@"@interface %@ : TechnicalIndicatorBase\n@end\n\n", className];
    
    // Implementation
    [code appendFormat:@"@implementation %@\n\n", className];
    
    // Properties from inputs
    for (PineScriptVariable *input in parseResult.inputs) {
        [code appendFormat:@"// Input: %@\n", input.name];
    }
    [code appendString:@"\n"];
    
    // Initialize method
    [code appendString:@"- (instancetype)initWithParameters:(NSDictionary<NSString *, id> *)parameters {\n"];
    [code appendString:@"    self = [super initWithParameters:parameters];\n"];
    [code appendString:@"    if (self) {\n"];
    [code appendFormat:@"        // Generated from: %@\n", parseResult.indicatorName ?: @"Custom Indicator"];
    [code appendString:@"    }\n"];
    [code appendString:@"    return self;\n"];
    [code appendString:@"}\n\n"];
    
    // Calculate method
    [code appendString:@"- (void)calculateWithBars:(NSArray<HistoricalBarModel *> *)bars {\n"];
    [code appendString:@"    // TODO: Implement calculation logic\n"];
    [code appendString:@"    // Generated from PineScript - manual implementation required\n"];
    [code appendString:@"}\n\n"];
    
    // Required properties
    [code appendString:@"- (NSString *)indicatorID {\n"];
    [code appendFormat:@"    return @\"%@\";\n", className];
    [code appendString:@"}\n\n"];
    
    [code appendString:@"- (NSString *)name {\n"];
    [code appendFormat:@"    return @\"%@\";\n", parseResult.indicatorName ?: className];
    [code appendString:@"}\n\n"];
    
    [code appendString:@"- (NSString *)shortName {\n"];
    [code appendFormat:@"    return @\"%@\";\n", parseResult.shortTitle ?: className];
    [code appendString:@"}\n\n"];
    
    [code appendString:@"- (NSInteger)minimumBarsRequired {\n"];
    [code appendString:@"    return 1; // TODO: Calculate from script requirements\n"];
    [code appendString:@"}\n\n"];
    
    [code appendString:@"@end"];
    
    return [code copy];
}


@end

