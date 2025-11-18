#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void binaryImageWasAdded(const SentryCrashBinaryImage *_Nullable image);

void binaryImageWasRemoved(const SentryCrashBinaryImage *_Nullable image);

#ifdef __cplusplus
}
#endif
