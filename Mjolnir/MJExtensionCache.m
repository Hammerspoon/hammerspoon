#import "MJExtensionCache.h"
#import "MJExtension.h"
#import "MJConfigUtils.h"

@implementation MJExtensionCache

+ (BOOL)supportsSecureCoding { return YES; }

+ (NSString*) file { return [MJConfigPath() stringByAppendingPathComponent:@".extcache"]; }

+ (MJExtensionCache*) cache {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self file]])
        return [NSKeyedUnarchiver unarchiveObjectWithFile:[self file]];
    else
        return [[MJExtensionCache alloc] init];
}

- (id) init {
    if (self = [super init]) {
        self.extensionsAvailable = [NSMutableArray array];
        self.extensionsInstalled = [NSMutableArray array];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.timestamp = [decoder decodeObjectOfClass:[NSNumber class] forKey:@"timestamp"];
        self.extensionsAvailable = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"extensionsAvailable"];
        self.extensionsInstalled = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"extensionsInstalled"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.timestamp forKey:@"timestamp"];
    [encoder encodeObject:self.extensionsAvailable forKey:@"extensionsAvailable"];
    [encoder encodeObject:self.extensionsInstalled forKey:@"extensionsInstalled"];
}

- (void) save {
    [[NSKeyedArchiver archivedDataWithRootObject:self] writeToFile:[MJExtensionCache file] atomically:YES];
}

@end
