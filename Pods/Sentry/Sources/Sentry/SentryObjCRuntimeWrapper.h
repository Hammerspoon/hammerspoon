#import <Foundation/Foundation.h>

@protocol SentryObjCRuntimeWrapper <NSObject>

- (int)getClassList:(__unsafe_unretained Class *)buffer bufferCount:(int)bufferCount;

@end
