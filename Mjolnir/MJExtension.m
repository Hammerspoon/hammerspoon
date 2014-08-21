#import "MJExtension.h"
#import "MJDocsManager.h"
#import "MJConfigManager.h"
#import "MJSecurityUtils.h"
#import "MJFileUtils.h"
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

+ (MJExtension*) extensionWithJSON:(NSDictionary*)json {
    MJExtension* ext = [[MJExtension alloc] init];
    ext.name = [json objectForKey:@"name"];
    ext.author = [json objectForKey:@"author"];
    ext.version = [json objectForKey:@"version"];
    ext.license = [json objectForKey:@"license"];
    ext.tarfile = [json objectForKey:@"tarfile"];
    ext.tarsha = [json objectForKey:@"sha"];
    ext.website = [json objectForKey:@"website"];
    ext.desc = [json objectForKey:@"description"];
    ext.dependencies = [json objectForKey:@"deps"];
    ext.changelog = [json objectForKey:@"changelog"];
    ext.previous = [json objectForKey:@"previous"];
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
    MJDownloadFile(self.tarfile, ^(NSError *err, NSData *tgzdata) {
        if (err) {
            done(err);
            return;
        }
        
        NSError* __autoreleasing error;
        if (!MJVerifyTgzData(tgzdata, self.tarsha, &error)) {
            NSMutableDictionary* userinfo = [@{NSLocalizedDescriptionKey: @"Extension's SHA1 doesn't hold up."} mutableCopy];
            if (error) [userinfo setObject:error forKey:NSUnderlyingErrorKey];
            done([NSError errorWithDomain:@"Mjolnir" code:0 userInfo:userinfo]);
            return;
        }
        
        NSString* extdir = [MJConfigManager dirForExtensionName:self.name];
        if (!MJUntar(tgzdata, extdir, &error)) {
            done(error);
            return;
        }
        
        MJLoadModule(self.name);
        
        if (![MJDocsManager installExtensionInDirectory:extdir error:&error]) {
            done(error);
            return;
        }
        
        done(nil);
    });
}

- (void) uninstall:(void(^)(NSError*))done {
    MJUnloadModule(self.name);
    
    NSError* __autoreleasing error;
    NSString* extdir = [MJConfigManager dirForExtensionName:self.name];
    if ([MJDocsManager uninstallExtensionInDirectory:extdir error:&error])
        error = nil;
    
    if ([[NSFileManager defaultManager] removeItemAtPath:extdir error:&error])
        error = nil;
    
    done(error);
}

@end
