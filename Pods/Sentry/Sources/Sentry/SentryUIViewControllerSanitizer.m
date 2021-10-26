#import "SentryUIViewControllerSanitizer.h"

@implementation SentryUIViewControllerSanitizer

+ (NSRegularExpression *)viewControllerRegex
{
    static dispatch_once_t onceTokenRegex;
    static NSRegularExpression *regex = nil;
    dispatch_once(&onceTokenRegex, ^{
        NSString *pattern = @"[<.](\\w+)";
        regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    return regex;
}

+ (NSString *)sanitizeViewControllerName:(id)controller
{
    NSString *description = [NSString stringWithFormat:@"%@", controller];

    NSRange searchedRange = NSMakeRange(0, [description length]);
    NSArray *matches = [[self.class viewControllerRegex] matchesInString:description
                                                                 options:0
                                                                   range:searchedRange];
    NSMutableArray *strings = [NSMutableArray array];
    for (NSTextCheckingResult *match in matches) {
        [strings addObject:[description substringWithRange:[match rangeAtIndex:1]]];
    }
    if ([strings count] > 0) {
        return [strings componentsJoinedByString:@"."];
    }
    return description;
}

@end
