//
//  PineScriptParser.h
//  TradingApp
//
//  Parser and validator for PineScript-like language
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - PineScript AST Nodes

@interface PineScriptFunction : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray<NSString *> *parameters;
@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, assign) NSInteger lineNumber;
@end

@interface PineScriptVariable : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) id value;
@property (nonatomic, strong) NSString *type; // "number", "string", "bool", "color"
@property (nonatomic, assign) NSInteger lineNumber;
@end

@interface PineScriptExpression : NSObject
@property (nonatomic, strong) NSString *expression;
@property (nonatomic, strong) NSString *resultType;
@property (nonatomic, assign) NSInteger lineNumber;
@end

#pragma mark - Parse Result

@interface PineScriptParseResult : NSObject
@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong, nullable) NSString *errorMessage;
@property (nonatomic, assign) NSInteger errorLine;
@property (nonatomic, assign) NSInteger errorColumn;
@property (nonatomic, strong) NSArray<NSString *> *warnings;

// Parsed elements
@property (nonatomic, strong, nullable) PineScriptFunction *studyDeclaration;
@property (nonatomic, strong) NSArray<PineScriptVariable *> *inputs;
@property (nonatomic, strong) NSArray<PineScriptVariable *> *variables;
@property (nonatomic, strong) NSArray<PineScriptFunction *> *plots;
@property (nonatomic, strong) NSArray<PineScriptFunction *> *functions;
@property (nonatomic, strong) NSArray<PineScriptExpression *> *expressions;

// Metadata
@property (nonatomic, strong, nullable) NSString *indicatorName;
@property (nonatomic, strong, nullable) NSString *shortTitle;
@property (nonatomic, assign) BOOL isOverlay;
@property (nonatomic, strong) NSArray<NSString *> *requiredBars;
@end

#pragma mark - PineScript Parser

@interface PineScriptParser : NSObject

#pragma mark - Parsing

/// Parse PineScript source code
/// @param script PineScript source code
/// @return Parse result with AST and validation info
+ (PineScriptParseResult *)parseScript:(NSString *)script;

/// Validate parsed script for common issues
/// @param parseResult Result from parseScript
/// @return Updated parse result with validation warnings/errors
+ (PineScriptParseResult *)validateParsedScript:(PineScriptParseResult *)parseResult;

#pragma mark - Built-in Functions and Constants

/// Get list of supported built-in functions
+ (NSArray<NSString *> *)supportedBuiltinFunctions;

/// Get list of supported constants
+ (NSArray<NSString *> *)supportedConstants;

/// Get list of supported input types
+ (NSArray<NSString *> *)supportedInputTypes;

/// Check if function is a built-in function
/// @param functionName Function name to check
+ (BOOL)isBuiltinFunction:(NSString *)functionName;

/// Get function signature for built-in function
/// @param functionName Built-in function name
/// @return Dictionary with parameter info or nil if not found
+ (nullable NSDictionary *)signatureForBuiltinFunction:(NSString *)functionName;

#pragma mark - Code Generation

/// Generate Objective-C indicator class from parsed script
/// @param parseResult Validated parse result
/// @param className Target class name
/// @return Generated Objective-C code or nil if generation fails
+ (nullable NSString *)generateObjectiveCIndicatorFromParseResult:(PineScriptParseResult *)parseResult
                                                        className:(NSString *)className;



NS_ASSUME_NONNULL_END
@end
