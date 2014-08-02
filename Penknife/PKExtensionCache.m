#import "PKExtensionCache.h"

@implementation PKExtensionCache

+ (BOOL)supportsSecureCoding { return YES; }

+ (NSString*) file { return [@"~/.penknife/.extcache" stringByStandardizingPath]; }

+ (PKExtensionCache*) cache {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[self file]])
        return [NSKeyedUnarchiver unarchiveObjectWithFile:[self file]];
    else
        return [[PKExtensionCache alloc] init];
}

- (id) init {
    if (self = [super init]) {
        self.extensions = [NSMutableArray array];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sha = [decoder decodeObjectOfClass:[NSString class] forKey:@"sha"];
        self.extensions = [decoder decodeObjectOfClass:[NSMutableArray class] forKey:@"extensions"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sha forKey:@"sha"];
    [encoder encodeObject:self.extensions forKey:@"extensions"];
}

- (void) save {
    [[NSFileManager defaultManager] createDirectoryAtPath:[@"~/.penknife/" stringByStandardizingPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    
    [[NSKeyedArchiver archivedDataWithRootObject:self] writeToFile:[PKExtensionCache file] atomically:YES];
}

@end
