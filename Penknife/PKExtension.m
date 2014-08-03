#import "PKExtension.h"

@implementation PKExtension

+ (BOOL)supportsSecureCoding { return YES; }

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super init]) {
        self.sha = [decoder decodeObjectOfClass:[NSString class] forKey:@"sha"];
        self.name = [decoder decodeObjectOfClass:[NSString class] forKey:@"name"];
        self.author = [decoder decodeObjectOfClass:[NSString class] forKey:@"author"];
        self.version = [decoder decodeObjectOfClass:[NSString class] forKey:@"version"];
        self.tarfile = [decoder decodeObjectOfClass:[NSString class] forKey:@"tarfile"];
        self.website = [decoder decodeObjectOfClass:[NSString class] forKey:@"website"];
        self.license = [decoder decodeObjectOfClass:[NSString class] forKey:@"license"];
        self.description = [decoder decodeObjectOfClass:[NSString class] forKey:@"description"];
        self.dependencies = [decoder decodeObjectOfClass:[NSArray class] forKey:@"dependencies"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:self.sha forKey:@"sha"];
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.author forKey:@"author"];
    [encoder encodeObject:self.version forKey:@"version"];
    [encoder encodeObject:self.tarfile forKey:@"tarfile"];
    [encoder encodeObject:self.website forKey:@"website"];
    [encoder encodeObject:self.license forKey:@"license"];
    [encoder encodeObject:self.description forKey:@"description"];
    [encoder encodeObject:self.dependencies forKey:@"dependencies"];
}

+ (PKExtension*) extensionWithShortJSON:(NSDictionary*)shortJSON longJSON:(NSDictionary*)longJSON {
    PKExtension* ext = [[PKExtension alloc] init];
    ext.sha = [shortJSON objectForKey: @"sha"];
    ext.name = [[shortJSON objectForKey: @"path"] stringByReplacingOccurrencesOfString:@".json" withString:@""];
    ext.author = [longJSON objectForKey:@"author"];
    ext.version = [longJSON objectForKey:@"version"];
    ext.license = [longJSON objectForKey:@"license"];
    ext.tarfile = [longJSON objectForKey:@"tarfile"];
    ext.website = [longJSON objectForKey:@"website"];
    ext.description = [longJSON objectForKey:@"description"];
    ext.dependencies = [longJSON objectForKey:@"deps"];
    return ext;
}

@end
