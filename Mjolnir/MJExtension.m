#import "MJExtension.h"
#import "MJDocsManager.h"
#import "MJConfigManager.h"
#import "core.h"

@implementation MJExtension

+ (BOOL)supportsSecureCoding { return YES; }

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sha = [decoder decodeObjectOfClass:[NSString class] forKey:@"sha"];
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        self.author = [decoder decodeObjectOfClass:[NSString class] forKey:@"author"];
        self.version = [decoder decodeObjectOfClass:[NSString class] forKey:@"version"];
        self.tarfile = [decoder decodeObjectOfClass:[NSString class] forKey:@"tarfile"];
        self.tarsha = [decoder decodeObjectOfClass:[NSString class] forKey:@"tarsha"];
        self.website = [decoder decodeObjectOfClass:[NSString class] forKey:@"website"];
        self.license = [decoder decodeObjectOfClass:[NSString class] forKey:@"license"];
        self.desc = [decoder decodeObjectOfClass:[NSString class] forKey:@"description"];
        self.dependencies = [decoder decodeObjectOfClass:[NSArray class] forKey:@"dependencies"];
        self.changelog = [decoder decodeObjectOfClass:[NSString class] forKey:@"changelog"];
        self.previous = [decoder decodeObjectOfClass:[NSString class] forKey:@"previous"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sha forKey:@"sha"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.author forKey:@"author"];
    [encoder encodeObject:self.version forKey:@"version"];
    [encoder encodeObject:self.tarfile forKey:@"tarfile"];
    [encoder encodeObject:self.tarsha forKey:@"tarsha"];
    [encoder encodeObject:self.website forKey:@"website"];
    [encoder encodeObject:self.license forKey:@"license"];
    [encoder encodeObject:self.desc forKey:@"description"];
    [encoder encodeObject:self.dependencies forKey:@"dependencies"];
    [encoder encodeObject:self.changelog forKey:@"changelog"];
    [encoder encodeObject:self.previous forKey:@"previous"];
}

+ (MJExtension*) extensionWithShortJSON:(NSDictionary*)shortJSON longJSON:(NSDictionary*)longJSON {
    MJExtension* ext = [[MJExtension alloc] init];
    ext.sha = [shortJSON objectForKey:@"sha"];
    ext.name = [[shortJSON objectForKey:@"path"] stringByReplacingOccurrencesOfString:@".json" withString:@""];
    ext.author = [longJSON objectForKey:@"author"];
    ext.version = [longJSON objectForKey:@"version"];
    ext.license = [longJSON objectForKey:@"license"];
    ext.tarfile = [longJSON objectForKey:@"tarfile"];
    ext.tarsha = [longJSON objectForKey:@"sha"];
    ext.website = [longJSON objectForKey:@"website"];
    ext.desc = [longJSON objectForKey:@"description"];
    ext.dependencies = [longJSON objectForKey:@"deps"];
    ext.changelog = [longJSON objectForKey:@"changelog"];
    ext.previous = [longJSON objectForKey:@"previous"];
    return ext;
}

- (BOOL) isEqual:(MJExtension*)other {
    return [self isKindOfClass:[other class]] && [self.tarsha isEqualToString: other.tarsha];
}

- (NSUInteger) hash {
    return [self.tarsha hash];
}

- (NSString*) description {
    return [NSString stringWithFormat:@"<Ext: %@ %@ - %@>", self.name, self.version, self.tarsha];
}

- (void) install:(void(^)(NSError*))done {
    [MJConfigManager downloadExtension:self.tarfile handler:^(NSError *err, NSData *tgzdata) {
        if (err) {
            done(err);
            return;
        }
        
        NSError* __autoreleasing error;
        if (![MJConfigManager verifyData:tgzdata sha:self.tarsha error:&error]) {
            done([NSError errorWithDomain:@"Mjolnir" code:0 userInfo:@{NSLocalizedDescriptionKey: @"SHA1 doesn't match.", NSUnderlyingErrorKey: error}]);
            return;
        }
        
        NSString* extdir = [MJConfigManager dirForExtensionName:self.name];
        BOOL success = [MJConfigManager untarData:tgzdata intoDirectory:extdir error:&error];
        if (!success) {
            done(error);
            return;
        }
        
        MJLoadModule(self.name);
        
        [MJDocsManager installExtension:self];
        
        done(nil);
    }];
}

- (void) uninstall:(void(^)(NSError*))done {
    [MJDocsManager uninstallExtension:self];
    
    MJUnloadModule(self.name);
    
    [[NSFileManager defaultManager] removeItemAtPath:[MJConfigManager dirForExtensionName:self.name] error:NULL];
    
    done(nil);
}

@end
