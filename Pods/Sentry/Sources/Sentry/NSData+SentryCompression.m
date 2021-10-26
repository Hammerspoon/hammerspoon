#if __has_include(<zlib.h>)
#    import <zlib.h>
#endif

#import "NSData+SentryCompression.h"
#import "SentryError.h"

NS_ASSUME_NONNULL_BEGIN

@implementation
NSData (SentryCompression)

- (NSData *_Nullable)sentry_gzippedWithCompressionLevel:(NSInteger)compressionLevel
                                                  error:(NSError *_Nullable *_Nullable)error
{
    uInt length = (uInt)[self length];
    if (length == 0) {
        return [NSData data];
    }

    /// Init empty z_stream
    z_stream stream;
    stream.zalloc = Z_NULL;
    stream.zfree = Z_NULL;
    stream.opaque = Z_NULL;
    stream.next_in = (Bytef *)(void *)self.bytes;
    stream.total_out = 0;
    stream.avail_out = 0;
    stream.avail_in = length;

    int err;

    err = deflateInit2(
        &stream, compressionLevel, Z_DEFLATED, (16 + MAX_WBITS), 9, Z_DEFAULT_STRATEGY);
    if (err != Z_OK) {
        if (error) {
            *error = NSErrorFromSentryError(kSentryErrorCompressionError, @"deflateInit2 error");
        }
        return nil;
    }

    NSMutableData *compressedData = [NSMutableData dataWithLength:(NSUInteger)(length * 1.02 + 50)];
    Bytef *compressedBytes = [compressedData mutableBytes];
    NSUInteger compressedLength = [compressedData length];

    /// compress
    while (err == Z_OK) {
        stream.next_out = compressedBytes + stream.total_out;
        stream.avail_out = (uInt)(compressedLength - stream.total_out);
        err = deflate(&stream, Z_FINISH);
    }

    [compressedData setLength:stream.total_out];

    deflateEnd(&stream);
    return compressedData;
}

@end

NS_ASSUME_NONNULL_END
