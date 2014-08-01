#import "PKExtManager.h"

@implementation PKExtManager

+ (PKExtManager*) sharedExtManager {
    static PKExtManager* sharedExtManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedExtManager = [[PKExtManager alloc] init];
    });
    return sharedExtManager;
}

@end
