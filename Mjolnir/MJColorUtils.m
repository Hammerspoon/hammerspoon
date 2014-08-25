#import "MJColorUtils.h"

NSColor* MJColorFromHex(const char* hex) {
    static NSMutableDictionary* colors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colors = [NSMutableDictionary dictionary];
    });
    
    NSString* hexString = [[NSString stringWithUTF8String: hex] uppercaseString];
    NSColor* color = [colors objectForKey:hexString];
    
    if (!color) {
        NSScanner* scanner = [NSScanner scannerWithString: hexString];
        unsigned colorCode = 0;
        [scanner scanHexInt:&colorCode];
        color = [NSColor colorWithCalibratedRed:(CGFloat)(unsigned char)(colorCode >> 16) / 0xff
                                          green:(CGFloat)(unsigned char)(colorCode >> 8) / 0xff
                                           blue:(CGFloat)(unsigned char)(colorCode) / 0xff
                                          alpha: 1.0];
        [colors setObject:color forKey:hexString];
    }
    
    return color;
}
