#import "Random.h"

@implementation Random

- (instancetype)init
{
    if (self = [super init]) {
        srand48(time(0)); // drand seed initializer
    }
    return self;
}

- (double)nextNumber
{
    return drand48();
}

@end
