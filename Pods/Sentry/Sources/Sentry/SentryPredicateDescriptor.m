#import "SentryPredicateDescriptor.h"

@implementation SentryPredicateDescriptor

- (NSString *)predicateDescription:(NSPredicate *)predicate
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        return [self compoundPredicateDescription:(NSCompoundPredicate *)predicate];
    } else if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        return [self comparisonPredicateDescription:(NSComparisonPredicate *)predicate];
    } else if ([predicate isKindOfClass:[NSExpression class]]) {
        return [self expressionDescription:(NSExpression *)predicate];
    }

    return @"<UNKNOWN PREDICATE>";
}

- (NSString *)compoundPredicateDescription:(NSCompoundPredicate *)predicate
{

    NSMutableArray<NSString *> *expressions =
        [[NSMutableArray alloc] initWithCapacity:predicate.subpredicates.count];

    for (NSPredicate *sub in predicate.subpredicates) {
        if ([sub isKindOfClass:[NSCompoundPredicate class]]) {
            [expressions
                addObject:[NSString stringWithFormat:@"(%@)", [self predicateDescription:sub]]];
        } else {
            [expressions addObject:[self predicateDescription:sub]];
        }
    }

    if (expressions.count == 1) {
        return [NSString stringWithFormat:@"%@ %@",
                         [self compoundPredicateTypeDescription:predicate.compoundPredicateType],
                         expressions.firstObject];
    }

    return [expressions
        componentsJoinedByString:[self
                                     compoundPredicateTypeDescription:predicate
                                                                          .compoundPredicateType]];
}

- (NSString *)comparisonPredicateDescription:(NSComparisonPredicate *)predicate
{
    NSString *operator= [self predicateOperatorTypeDescription:predicate.predicateOperatorType];

    if (operator== nil) {
        return @"<COMPARISON NOT SUPPORTED>";
    }

    return [NSString stringWithFormat:@"%@ %@ %@",[self expressionDescription:predicate.leftExpression] ,
            operator,
            [self expressionDescription:predicate.rightExpression]
    ];
}

- (NSString *)expressionDescription:(NSExpression *)predicate
{
    switch (predicate.expressionType) {
    case NSConstantValueExpressionType:
        return @"%@";
    case NSAggregateExpressionType:
        if ([predicate.collection isKindOfClass:[NSArray class]]) {
            __block NSMutableArray *items =
                [[NSMutableArray alloc] initWithCapacity:[predicate.collection count]];
            [predicate.collection enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [items addObject:[self expressionDescription:obj]];
            }];
            return [NSString stringWithFormat:@"{%@}", [items componentsJoinedByString:@", "]];
        } else {
            return @"%@";
        }
        break;
    case NSConditionalExpressionType:
        if (@available(macOS 10.11, *)) {
            return [NSString
                stringWithFormat:@"TERNARY(%@,%@,%@)",
                [self comparisonPredicateDescription:(NSComparisonPredicate *)predicate.predicate],
                [self expressionDescription:predicate.trueExpression],
                [self expressionDescription:predicate.falseExpression]];
        } else {
            // this is not supposed to happen, NSConditionalExpressionType was introduced in
            // macOS 10.11 but we need this version check because cocoapod lint check is failing
            // without it.
            return @"<EXPRESSION UNKNOWN>";
        }
    default:
        return predicate.description;
    }
}

- (NSString *)compoundPredicateTypeDescription:(NSCompoundPredicateType)compountType
{
    switch (compountType) {
    case NSAndPredicateType:
        return @" AND ";
    case NSOrPredicateType:
        return @" OR ";
    case NSNotPredicateType:
        return @"NOT";
    default:
        return @", ";
    }
}

- (NSString *)predicateOperatorTypeDescription:(NSPredicateOperatorType)operator
{
    switch (operator) {
    case NSLessThanPredicateOperatorType:
        return @"<";
    case NSLessThanOrEqualToPredicateOperatorType:
        return @"<=";
    case NSGreaterThanPredicateOperatorType:
        return @">";
    case NSGreaterThanOrEqualToPredicateOperatorType:
        return @">=";
    case NSEqualToPredicateOperatorType:
        return @"==";
    case NSNotEqualToPredicateOperatorType:
        return @"!=";
    case NSMatchesPredicateOperatorType:
        return @"MATCHES";
    case NSBeginsWithPredicateOperatorType:
        return @"BEGINSWITH";
    case NSEndsWithPredicateOperatorType:
        return @"ENDSWITH";
    case NSInPredicateOperatorType:
        return @"IN";
    case NSContainsPredicateOperatorType:
        return @"CONTAINS";
    case NSBetweenPredicateOperatorType:
        return @"BETWEEN";
    case NSLikePredicateOperatorType:
        return @"LIKE";
    // NSCustomSelectorPredicateOperatorType is Not supported for CoreData
    default:
        return nil;
    }
}

@end
