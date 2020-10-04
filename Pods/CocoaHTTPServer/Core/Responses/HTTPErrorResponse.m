#import "HTTPErrorResponse.h"

@implementation HTTPErrorResponse

-(id)initWithErrorCode:(int)httpErrorCode
{
    if ((self = [super init]))
    {
        _status = httpErrorCode;
    }

    return self;
}

- (UInt64) contentLength {
    return 0;
}

- (UInt64) offset {
    return 0;
}

- (void)setOffset:(UInt64)offset {
    ;
}

- (NSData*) readDataOfLength:(NSUInteger)length {
    return nil;
}

- (BOOL) isDone {
    return YES;
}

- (NSInteger) status {
    return _status;
}
@end
