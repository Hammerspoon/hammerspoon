#import "HTTPMessage.h"

#if ! __has_feature(objc_arc)
#warning This file must be compiled with ARC. Use -fobjc-arc flag (or convert project to ARC).
#endif


@implementation HTTPMessage

- (id)initEmptyRequest
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateEmpty(NULL, YES);
	}
	return self;
}

- (id)initRequestWithMethod:(NSString *)method URL:(NSURL *)url version:(NSString *)version
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateRequest(NULL,
		                                    (__bridge CFStringRef)method,
		                                    (__bridge CFURLRef)url,
		                                    (__bridge CFStringRef)version);
	}
	return self;
}

- (id)initResponseWithStatusCode:(NSInteger)code description:(NSString *)description version:(NSString *)version
{
	if ((self = [super init]))
	{
		message = CFHTTPMessageCreateResponse(NULL,
		                                      (CFIndex)code,
		                                      (__bridge CFStringRef)description,
		                                      (__bridge CFStringRef)version);
	}
	return self;
}

- (void)dealloc
{
	if (message)
	{
		CFRelease(message);
	}
}

- (BOOL)appendData:(NSData *)data
{
	return CFHTTPMessageAppendBytes(message, [data bytes], [data length]);
}

- (BOOL)isHeaderComplete
{
	return CFHTTPMessageIsHeaderComplete(message);
}

- (NSString *)version
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyVersion(message);
}

- (NSString *)method
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyRequestMethod(message);
}

- (NSURL *)url
{
	return (__bridge_transfer NSURL *)CFHTTPMessageCopyRequestURL(message);
}

- (NSInteger)statusCode
{
	return (NSInteger)CFHTTPMessageGetResponseStatusCode(message);
}

- (NSDictionary *)allHeaderFields
{
	return (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);
}

- (NSString *)headerField:(NSString *)headerField
{
	return (__bridge_transfer NSString *)CFHTTPMessageCopyHeaderFieldValue(message, (__bridge CFStringRef)headerField);
}

- (void)setHeaderField:(NSString *)headerField value:(NSString *)headerFieldValue
{
	CFHTTPMessageSetHeaderFieldValue(message,
	                                 (__bridge CFStringRef)headerField,
	                                 (__bridge CFStringRef)headerFieldValue);
}

- (NSData *)messageData
{
	return (__bridge_transfer NSData *)CFHTTPMessageCopySerializedMessage(message);
}

- (NSData *)body
{
	return (__bridge_transfer NSData *)CFHTTPMessageCopyBody(message);
}

- (void)setBody:(NSData *)body
{
	CFHTTPMessageSetBody(message, (__bridge CFDataRef)body);
}

@end
