#import "MJExtensionCache.h"
#import "MJExtension.h"
#import "MJConfigManager.h"

@implementation MJExtensionCache

+ (BOOL)supportsSecureCoding { return YES; }

+ (NSString*) file { return [[MJConfigManager configPath] stringByAppendingPathComponent:@".extcache"]; }

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
        self.sha = [decoder decodeObjectOfClass:[NSString class] forKey:@"sha"];
        self.extensionsAvailable = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"extensionsAvailable"];
        self.extensionsInstalled = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"extensionsInstalled"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sha forKey:@"sha"];
    [encoder encodeObject:self.extensionsAvailable forKey:@"extensionsAvailable"];
    [encoder encodeObject:self.extensionsInstalled forKey:@"extensionsInstalled"];
}

- (void) save {
    [[NSKeyedArchiver archivedDataWithRootObject:self] writeToFile:[MJExtensionCache file] atomically:YES];
}

@end
