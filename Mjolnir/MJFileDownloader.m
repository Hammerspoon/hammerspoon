#import "MJFileDownloader.h"

@implementation MJFileDownloader

+ (void) downloadExtension:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler {
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               handler(connectionError, data);
                           }];
}

@end
