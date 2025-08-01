#import "SentryCrashDynamicLinker.h"

// Added for tests
extern void sentrycrashdl_clearDyld(void);
struct dyld_all_image_infos *getAllImageInfo(void);
extern uint32_t imageIndexContainingAddress(const uintptr_t address);
extern uintptr_t firstCmdAfterHeader(const struct mach_header *const header);
extern SentrySegmentAddress getSegmentAddress(
    const struct mach_header *header, const char *segmentName);
