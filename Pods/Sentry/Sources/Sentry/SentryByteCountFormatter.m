#import "SentryByteCountFormatter.h"

@implementation SentryByteCountFormatter

+ (NSString *)bytesCountDescription:(unsigned long)bytes
{
    const NSArray *units = @[ @"bytes", @"KB", @"MB", @"GB" ];
    int index = 0;

    double result = bytes;

    while (result >= 1024 && index < units.count - 1) {
        result /= 1024.0;
        index++;
    }

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
    [formatter setNumberStyle:NSNumberFormatterDecimalStyle];
    [formatter setRoundingMode:NSNumberFormatterRoundFloor];
    [formatter setPositiveFormat:@"#,##0"];

    return [NSString stringWithFormat:@"%@ %@",
                     [formatter stringFromNumber:[NSNumber numberWithDouble:result]], units[index]];
}

@end
