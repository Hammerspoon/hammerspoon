@import Cocoa ;
@import LuaSkin ;
@import Darwin.sys.sysctl ;
@import Darwin.POSIX.sys.types ;
@import Darwin.Mach ;
@import Darwin.Mach.processor_info ;
@import Darwin.Mach.host_info ;
@import Darwin.Mach.mach_host ;
@import Darwin.Mach.task_info ;
@import Darwin.Mach.task ;

/// hs.host.addresses() -> table
/// Function
/// Gets a list of network addresses for the current machine
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of strings containing the network addresses of the current machine
///
/// Notes:
///  * The results will include IPv4 and IPv6 addresses
static int hostAddresses(lua_State* L) {
    NSArray *addresses = [[NSHost currentHost] addresses];
    if (!addresses) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int i = 1;
    for (NSString *address in addresses) {
        lua_pushinteger(L, i++);
        lua_pushstring(L, [address UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.host.names() -> table
/// Function
/// Gets a list of network names for the current machine
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of strings containing the network names of the current machine
///
/// Notes:
///  * This function should be used sparingly, as it may involve blocking network access to resolve hostnames
static int hostNames(lua_State* L) {
    NSArray *names = [[NSHost currentHost] names];
    if (!names) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int i = 1;
    for (NSString *name in names) {
        lua_pushinteger(L, i++);
        lua_pushstring(L, [name UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.host.localizedName() -> string
/// Function
/// Gets the name of the current machine, as displayed in the Finder sidebar
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the current machine
static int hostLocalizedName(lua_State* L) {
    lua_pushstring(L, [[[NSHost currentHost] localizedName] UTF8String]);
    return 1;
}

/// hs.host.vmStat() -> table
/// Function
/// Returns a table containing virtual memory statistics for the current machine, as well as the page size (in bytes) and physical memory size (in bytes).
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys:
///    * anonymousPages          -- the total number of pages that are anonymous
///    * cacheHits               -- number of object cache hits
///    * cacheLookups            -- number of object cache lookups
///    * fileBackedPages         -- the total number of pages that are file-backed (non-swap)
///    * memSize                 -- physical memory size in bytes
///    * pageIns                 -- the total number of requests for pages from a pager (such as the inode pager).
///    * pageOuts                -- the total number of pages that have been paged out.
///    * pageSize                -- page size in bytes
///    * pagesActive             -- the total number of pages currently in use and pageable.
///    * pagesCompressed         -- the total number of pages that have been compressed by the VM compressor.
///    * pagesCopyOnWrite        -- the number of faults that caused a page to be copied (generally caused by copy-on-write faults).
///    * pagesDecompressed       -- the total number of pages that have been decompressed by the VM compressor.
///    * pagesFree               -- the total number of free pages in the system.
///    * pagesInactive           -- the total number of pages on the inactive list.
///    * pagesPurgeable          -- the total number of purgeable pages.
///    * pagesPurged             -- the total number of pages that have been purged.
///    * pagesReactivated        -- the total number of pages that have been moved from the inactive list to the active list (reactivated).
///    * pagesSpeculative        -- the total number of pages on the speculative list.
///    * pagesThrottled          -- the total number of pages on the throttled list (not wired but not pageable).
///    * pagesUsedByVMCompressor -- the number of pages used to store compressed VM pages.
///    * pagesWiredDown          -- the total number of pages wired down. That is, pages that cannot be paged out.
///    * pagesZeroFilled         -- the total number of pages that have been zero-filled on demand.
///    * swapIns                 -- the total number of compressed pages that have been swapped out to disk.
///    * swapOuts                -- the total number of compressed pages that have been swapped back in from disk.
///    * translationFaults       -- the number of times the "vm_fault" routine has been called.
///    * uncompressedPages       -- the total number of pages (uncompressed) held within the compressor
///
/// Notes:
///  * The table returned has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.host.vmStats()`.
///  * Except for the addition of cacheHits, cacheLookups, pageSize and memSize, the results for this function should be identical to the OS X command `vm_stat`.
///  * Adapted primarily from the source code to Apple's vm_stat command located at http://www.opensource.apple.com/source/system_cmds/system_cmds-643.1.1/vm_stat.tproj/vm_stat.c
static int hs_vmstat(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    int mib[6];
    mib[0] = CTL_HW; mib[1] = HW_PAGESIZE;

    uint32_t pagesize;
    size_t length;
    length = sizeof (pagesize);
    if (sysctl (mib, 2, &pagesize, &length, NULL, 0) < 0) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting page size (%d): %s", errno, strerror(errno)) ;
        [skin logError:[NSString stringWithFormat:@"hs.host.vmStat() error: %s", errStr]];
        return 0 ;
    }

    mib[0] = CTL_HW; mib[1] = HW_MEMSIZE;
    uint64_t memsize;
    length = sizeof (memsize);
    if (sysctl (mib, 2, &memsize, &length, NULL, 0) < 0) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting mem size (%d): %s", errno, strerror(errno)) ;
        [skin logError:[NSString stringWithFormat:@"hs.host.vmStat() error: %s", errStr]];
        return 0 ;
    }

    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;

    vm_statistics64_data_t vm_stat;
    kern_return_t retVal = host_statistics64 (mach_host_self (), HOST_VM_INFO64, (host_info_t) &vm_stat, &count);

    if (retVal != KERN_SUCCESS) {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting VM Statistics: %s", mach_error_string(retVal)) ;
        [skin logError:[NSString stringWithFormat:@"hs.host.vmStat() error: %s", errStr]];
        return 0 ;
    }

    lua_newtable(L) ;
        lua_pushinteger(L, (vm_stat.free_count - vm_stat.speculative_count)) ;            lua_setfield(L, -2, "pagesFree") ;
        lua_pushinteger(L, vm_stat.active_count) ;                                        lua_setfield(L, -2, "pagesActive") ;
        lua_pushinteger(L, vm_stat.inactive_count) ;                                      lua_setfield(L, -2, "pagesInactive") ;
        lua_pushinteger(L, vm_stat.speculative_count) ;                                   lua_setfield(L, -2, "pagesSpeculative") ;
        lua_pushinteger(L, vm_stat.throttled_count) ;                                     lua_setfield(L, -2, "pagesThrottled") ;
        lua_pushinteger(L, vm_stat.wire_count) ;                                          lua_setfield(L, -2, "pagesWiredDown") ;
        lua_pushinteger(L, vm_stat.purgeable_count) ;                                     lua_setfield(L, -2, "pagesPurgeable") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.faults) ;                                 lua_setfield(L, -2, "translationFaults") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.cow_faults) ;                             lua_setfield(L, -2, "pagesCopyOnWrite") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.zero_fill_count) ;                        lua_setfield(L, -2, "pagesZeroFilled") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.reactivations) ;                          lua_setfield(L, -2, "pagesReactivated") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.purges) ;                                 lua_setfield(L, -2, "pagesPurged") ;
        lua_pushinteger(L, vm_stat.external_page_count) ;                                 lua_setfield(L, -2, "fileBackedPages") ;
        lua_pushinteger(L, vm_stat.internal_page_count) ;                                 lua_setfield(L, -2, "anonymousPages") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.total_uncompressed_pages_in_compressor) ; lua_setfield(L, -2, "uncompressedPages") ;
        lua_pushinteger(L, vm_stat.compressor_page_count) ;                               lua_setfield(L, -2, "pagesUsedByVMCompressor") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.decompressions) ;                         lua_setfield(L, -2, "pagesDecompressed") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.compressions) ;                           lua_setfield(L, -2, "pagesCompressed") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.pageins) ;                                lua_setfield(L, -2, "pageIns") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.pageouts) ;                               lua_setfield(L, -2, "pageOuts") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.swapins) ;                                lua_setfield(L, -2, "swapIns") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.swapouts) ;                               lua_setfield(L, -2, "swapOuts") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.lookups) ;                                lua_setfield(L, -2, "cacheLookups") ;
        lua_pushinteger(L, (lua_Integer)vm_stat.hits) ;                                   lua_setfield(L, -2, "cacheHits") ;
        lua_pushinteger(L, pagesize) ;                                                    lua_setfield(L, -2, "pageSize") ;
        lua_pushinteger(L, (lua_Integer)memsize) ;                                        lua_setfield(L, -2, "memSize") ;
    return 1 ;
}

/// hs.host.cpuUsageTicks() -> table
/// Function
/// Returns a table containing the current cpu usage information for the system in `ticks` since the most recent system boot.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following:
///    * Individual tables, indexed by the core number, for each CPU core with the following keys in each subtable:
///      * user   -- number of ticks the cpu core has spent in user mode since system startup.
///      * system -- number of ticks the cpu core has spent in system mode since system startup.
///      * nice   --
///      * active -- For convenience, when you just want the total CPU usage, this is the sum of user, system, and nice.
///      * idle   -- number of ticks the cpu core has spent idle
///    * The key `overall` containing the same keys as described above but based upon the combined total of all cpu cores for the system.
///    * The key `n` containing the number of cores detected.
///
/// Notes:
///  * CPU mode ticks are updated during system interrupts and are incremented based upon the mode the CPU is in at the time of the interrupt. By its nature, this is always going to be approximate, and a single call to this function will return the current tick values since the system was last rebooted.
///  * To generate a snapshot of the system's usage "at this moment", you must take two samples and calculate the difference between them.  The [hs.host.cpuUsage](#cpuUsage) function is a wrapper which does this for you and returns the cpu usage statistics as a percentage of the total number of ticks which occurred during the sample period you specify when invoking `hs.host.cpuUsage`.
///
///  * Historically on Unix based systems, the `nice` cpu state represents processes for which the execution priority has been reduced to allow other higher priority processes access to more system resources.  The source code for the version of the [XNU Kernel](https://opensource.apple.com/source/xnu/xnu-3789.41.3/) currently provided by Apple (for macOS 10.12.3) shows this value as returned by the `host_processor_info` as hardcoded to 0.  For completeness, this value *is* included in the statistics returned by this function, but unless Apple makes a change in the future, it is not expected to provide any useful information.
///
///  * Adapted primarily from code found at http://stackoverflow.com/questions/6785069/get-cpu-percent-usage
static int hs_cpuUsageTicks(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK] ;

    unsigned numCPUs;
    int mib[2U] = { CTL_HW, HW_NCPU };
    size_t sizeOfNumCPUs = sizeof(numCPUs);
    int status = sysctl(mib, 2U, &numCPUs, &sizeOfNumCPUs, NULL, 0U);
    if(status) numCPUs = 1;  // On error, assume single cpu, single core

    processor_info_array_t cpuInfo ;
    mach_msg_type_number_t numCpuInfo ;
    natural_t numCPUsU = 0U;
    kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo);

    if(err == KERN_SUCCESS) {
        uint64_t overallInUser   = 0 ;
        uint64_t overallInSystem = 0 ;
        uint64_t overallInNice   = 0 ;
        uint64_t overallInIdle   = 0 ;
        uint64_t overallInUse    = 0 ;
        uint64_t overallTotal    = 0 ;
        lua_newtable(L) ;
        for(unsigned i = 0U; i < numCPUs; ++i) {
            uint32_t inUser   = (uint32_t)cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] ;
            uint32_t inSystem = (uint32_t)cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] ;
            uint32_t inNice   = (uint32_t)cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE] ;
            uint32_t inIdle   = (uint32_t)cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] ;
            uint32_t inUse    = inUser + inSystem + inNice ;
            uint32_t total    = inUse + inIdle ;

            overallInUser   += inUser ;
            overallInSystem += inSystem ;
            overallInNice   += inNice ;
            overallInIdle   += inIdle ;
            overallInUse    += inUse ;
            overallTotal    += total ;

            lua_newtable(L) ;
                lua_pushinteger(L, inUser) ;   lua_setfield(L, -2, "user") ;
                lua_pushinteger(L, inSystem) ; lua_setfield(L, -2, "system") ;
                lua_pushinteger(L, inNice) ;   lua_setfield(L, -2, "nice") ;
                lua_pushinteger(L, inUse) ;    lua_setfield(L, -2, "active") ;
                lua_pushinteger(L, inIdle) ;   lua_setfield(L, -2, "idle") ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1);  // Insert this table at end of result table
        }
        lua_newtable(L) ;
            lua_pushinteger(L, (lua_Integer)overallInUser) ;   lua_setfield(L, -2, "user") ;
            lua_pushinteger(L, (lua_Integer)overallInSystem) ; lua_setfield(L, -2, "system") ;
            lua_pushinteger(L, (lua_Integer)overallInNice) ;   lua_setfield(L, -2, "nice") ;
            lua_pushinteger(L, (lua_Integer)overallInUse) ;    lua_setfield(L, -2, "active") ;
            lua_pushinteger(L, (lua_Integer)overallInIdle) ;   lua_setfield(L, -2, "idle") ;
        lua_setfield(L, -2, "overall") ;
        vm_deallocate(mach_task_self(), (vm_address_t)cpuInfo, sizeof(integer_t) * numCpuInfo);
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.host.cpuUsage() error: %s", mach_error_string(err)]];
        return 0 ;
    }

    lua_pushinteger(L, numCPUs) ; lua_setfield(L, -2, "n") ;
    return 1 ;
}


/// hs.host.operatingSystemVersionString() -> string
/// Function
/// The operating system version as a human readable string.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The operating system version as a human readable string.
///
/// Notes:
///  * According to the OS X Developer documentation, "The operating system version string is human readable, localized, and is appropriate for displaying to the user. This string is not appropriate for parsing."
static int hs_operatingSystemVersionString(lua_State *L) {
    NSProcessInfo *pinfo = [NSProcessInfo processInfo];
    lua_pushstring(L, [[pinfo operatingSystemVersionString] UTF8String]) ;
    return 1 ;
}

/// hs.host.thermalState() -> string
/// Function
/// The current thermal state of the computer, as a human readable string
///
/// Parameters:
///  * None
///
/// Returns:
///  * The system's thermal state as a human readable string
static int hs_thermalStateString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    NSProcessInfoThermalState state = [NSProcessInfo processInfo].thermalState;
    NSString *returnState = nil;

    switch (state) {
        case NSProcessInfoThermalStateNominal:
            returnState = @"nominal";
            break;

        case NSProcessInfoThermalStateFair:
            returnState = @"fair";
            break;

        case NSProcessInfoThermalStateSerious:
            returnState = @"serious";
            break;

        case NSProcessInfoThermalStateCritical:
            returnState = @"critical";
            break;

        default:
            returnState = @"unknown";
            break;
    }

    [skin pushNSObject:returnState];
    return 1;
}

/// hs.host.operatingSystemVersion() -> table
/// Function
/// The operating system version as a table containing the major, minor, and patch numbers.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The operating system version as a table containing the keys major, minor, and patch corresponding to the version number determined and a key named "exact" or "approximation" depending upon the method used to determine the OS Version information.
///
/// Notes:
///  * Prior to 10.10 (Yosemite), there was no definitive way to reliably get an exact OS X version number without either mapping it to the Darwin kernel version, mapping it to the AppKitVersionNumber (the recommended method), or parsing the result of NSProcessingInfo's `operatingSystemVersionString` selector, which Apple states is not guaranteed to be reliably parseable.
///    * for OS X versions prior to 10.10, the version number is approximately determined by evaluating the AppKitVersionNumber.  For these operating systems, the `approximate` key is defined and set to true, as the exact patch level cannot be definitively determined.
///    * for OS X Versions starting at 10.10 and going forward, an exact value for the version number can be determined with NSProcessingInfo's `operatingSystemVersion` selector and the `exact` key is defined and set to true if this method is used.
static int hs_operatingSystemVersion(lua_State *L) {
    NSProcessInfo *pinfo = [NSProcessInfo processInfo];

    lua_newtable(L) ;
    if ([pinfo respondsToSelector:@selector(operatingSystemVersion)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        NSOperatingSystemVersion OSV = [pinfo operatingSystemVersion] ;
#pragma clang diagnostic pop
        lua_pushinteger(L, OSV.majorVersion) ; lua_setfield(L, -2, "major") ;
        lua_pushinteger(L, OSV.minorVersion) ; lua_setfield(L, -2, "minor") ;
        lua_pushinteger(L, OSV.patchVersion) ; lua_setfield(L, -2, "patch") ;
        lua_pushboolean(L, YES)              ; lua_setfield(L, -2, "exact") ;
    } else {

// If you try compiling this on OS Version < 10.8, I'm assuming you know what you're doing,
// because you're on your own...  You can add more of these if you need them.

// from NSApplication.h

#ifndef NSAppKitVersionNumber10_8
#define NSAppKitVersionNumber10_8 1187
#endif

#ifndef NSAppKitVersionNumber10_9
#define NSAppKitVersionNumber10_9 1265
#endif

#ifndef NSAppKitVersionNumber10_10
#define NSAppKitVersionNumber10_10 1343
#endif

        const double OSV = NSAppKitVersionNumber ;
        int major, minor, patch ;

        major = 10 ;
        if ( OSV >= NSAppKitVersionNumber10_0 && OSV < NSAppKitVersionNumber10_1 ) {
            minor = 0 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_1 && OSV < NSAppKitVersionNumber10_2 ) {
            minor = 1 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_2 && OSV < NSAppKitVersionNumber10_2_3 ) {
            minor = 2 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_2_3 && OSV < NSAppKitVersionNumber10_3 ) {
            minor = 2 ; patch = 3 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3 && OSV < NSAppKitVersionNumber10_3_2 ) {
            minor = 3 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3_2 && OSV < NSAppKitVersionNumber10_3_3 ) {
            minor = 3 ; patch = 2 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3_3 && OSV < NSAppKitVersionNumber10_3_5 ) {
            minor = 3 ; patch = 3 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3_5 && OSV < NSAppKitVersionNumber10_3_7 ) {
            minor = 3 ; patch = 5 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3_7 && OSV < NSAppKitVersionNumber10_3_9 ) {
            minor = 3 ; patch = 7 ;
        } else if ( OSV >= NSAppKitVersionNumber10_3_9 && OSV < NSAppKitVersionNumber10_4 ) {
            minor = 3 ; patch = 9 ;
        } else if ( OSV >= NSAppKitVersionNumber10_4 && OSV < NSAppKitVersionNumber10_4_1 ) {
            minor = 4 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_4_1 && OSV < NSAppKitVersionNumber10_4_3 ) {
            minor = 4 ; patch = 1 ;
        } else if ( OSV >= NSAppKitVersionNumber10_4_3 && OSV < NSAppKitVersionNumber10_4_4 ) {
            minor = 4 ; patch = 3 ;
        } else if ( OSV >= NSAppKitVersionNumber10_4_4 && OSV < NSAppKitVersionNumber10_4_7 ) {
            minor = 4 ; patch = 4 ;
        } else if ( OSV >= NSAppKitVersionNumber10_4_7 && OSV < NSAppKitVersionNumber10_5 ) {
            minor = 4 ; patch = 7 ;
        } else if ( OSV >= NSAppKitVersionNumber10_5 && OSV < NSAppKitVersionNumber10_5_2 ) {
            minor = 5 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_5_2 && OSV < NSAppKitVersionNumber10_5_3 ) {
            minor = 5 ; patch = 2 ;
        } else if ( OSV >= NSAppKitVersionNumber10_5_3 && OSV < NSAppKitVersionNumber10_6 ) {
            minor = 5 ; patch = 3 ;
        } else if ( OSV >= NSAppKitVersionNumber10_6 && OSV < NSAppKitVersionNumber10_7 ) {
            minor = 6 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_7 && OSV < NSAppKitVersionNumber10_7_2 ) {
            minor = 7 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_7_2 && OSV < NSAppKitVersionNumber10_7_3 ) {
            minor = 7 ; patch = 2 ;
        } else if ( OSV >= NSAppKitVersionNumber10_7_3 && OSV < NSAppKitVersionNumber10_7_4 ) {
            minor = 7 ; patch = 3 ;
        } else if ( OSV >= NSAppKitVersionNumber10_7_4 && OSV < NSAppKitVersionNumber10_8 ) {
            minor = 7 ; patch = 4 ;
        } else if ( OSV >= NSAppKitVersionNumber10_8 && OSV < NSAppKitVersionNumber10_9 ) {
            minor = 8 ; patch = 0 ;
        } else if ( OSV >= NSAppKitVersionNumber10_9 && OSV < NSAppKitVersionNumber10_10 ) {
            minor = 9 ; patch = 0 ;
        } else { // if ( OSV >= NSAppKitVersionNumber10_10) {
            minor = 10 ; patch = 0 ; // shouldn't ever get here -- operatingSystemVersion exists for you
        }
        lua_pushinteger(L, major) ; lua_setfield(L, -2, "major") ;
        lua_pushinteger(L, minor) ; lua_setfield(L, -2, "minor") ;
        lua_pushinteger(L, patch) ; lua_setfield(L, -2, "patch") ;
        lua_pushboolean(L, YES)   ; lua_setfield(L, -2, "approximation") ;
    }

    return 1 ;
}

/// hs.host.interfaceStyle() -> string
/// Function
/// Returns the OS X interface style for the current user.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string representing the current user interface style, or nil if the default style is in use.
///
/// Notes:
///  * As of OS X 10.10.4, other than the default style, only "Dark" is recognized as a valid style.
static int hs_interfaceStyle(lua_State *L) {
    lua_pushstring(L, [[[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] UTF8String]) ;
    return 1 ;
}

/// hs.host.uuid() -> string
/// Function
/// Returns a newly generated UUID as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * a newly generated UUID as a string
///
/// Notes:
///  * See also `hs.host.globallyUniqueString`
///  * UUIDs (Universally Unique Identifiers), also known as GUIDs (Globally Unique Identifiers) or IIDs (Interface Identifiers), are 128-bit values. UUIDs created by NSUUID conform to RFC 4122 version 4 and are created with random bytes.
static int hs_uuid(lua_State* L) {
    lua_pushstring(L, [[[NSUUID UUID] UUIDString] UTF8String]);
    return 1;
}


/// hs.host.globallyUniqueString() -> string
/// Function
/// Returns a newly generated global unique identifier as a string
///
/// Parameters:
///  * None
///
/// Returns:
///  * a newly generated global unique identifier as a string
///
/// Notes:
///  * See also `hs.host.uuid`
///  * The global unique identifier for a process includes the host name, process ID, and a time stamp, which ensures that the ID is unique for the network. This property generates a new string each time it is invoked, and it uses a counter to guarantee that strings are unique.
///  * This is often used as a file or directory name in conjunction with `hs.host.temporaryDirectory()` when creating temporary files.
static int hs_globallyUniqueString(lua_State* L) {
    lua_pushstring(L, [[[NSProcessInfo processInfo] globallyUniqueString] UTF8String]);
    return 1;
}

/// hs.host.idleTime() -> seconds
/// Function
/// Returns the number of seconds the computer has been idle.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the idle time in seconds
///
/// Notes:
///  * Idle time is defined as no mouse move nor keyboard entry, etc. and is determined by querying the HID (Human Interface Device) subsystem.
///  * This code is directly inspired by code found at http://www.xs-labs.com/en/archives/articles/iokit-idle-time/
static int hs_idleTime(lua_State *L) {
    mach_port_t            ioPort ;
    io_iterator_t          ioIterator;
    CFMutableDictionaryRef properties ;
    uint64_t               time;

    kern_return_t status = IOMasterPort(MACH_PORT_NULL, &ioPort) ;
    if (status != KERN_SUCCESS) return luaL_error(L, "Error communicating with IOKit: %d", status) ;

    status = IOServiceGetMatchingServices(ioPort, IOServiceMatching( "IOHIDSystem" ), &ioIterator);
    if (status != KERN_SUCCESS) return luaL_error(L, "Error accessing IOHIDSystem: %d", status) ;

    io_object_t ioObject = IOIteratorNext(ioIterator);
    if (ioObject == 0) {
        IOObjectRelease(ioIterator);
        return luaL_error(L, "Invalid iterator returned for IOHIDSystem") ;
    }

    status = IORegistryEntryCreateCFProperties(ioObject, &properties, kCFAllocatorDefault, 0);
    if (status != KERN_SUCCESS || properties == NULL) {
        IOObjectRelease(ioIterator);
        return luaL_error(L, "Cannot get system properties for IOHIDSystem: %d", status) ;
    }

    CFTypeRef idle = CFDictionaryGetValue(properties, CFSTR("HIDIdleTime")) ;
    if (!idle) {
        IOObjectRelease(ioIterator) ;
        CFRelease(properties) ;
        return luaL_error(L, "Cannot get system idle time from system properties for IOHIDSystem: %d", status) ;
    }

    CFTypeID type = CFGetTypeID( idle ); // could be data type or number type
    if (type == CFDataGetTypeID()) {
        CFDataGetBytes((CFDataRef)idle, CFRangeMake(0, sizeof(time)), (UInt8 *)&time) ;
    } else if (type == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)idle, kCFNumberSInt64Type, &time) ;
    } else {
        IOObjectRelease(ioIterator) ;
        CFRelease(properties) ;
        return luaL_error(L, "Unsupported type %d for HIDIdleTime", type) ;
    }

    IOObjectRelease(ioIterator) ;
    CFRelease(properties) ;

    lua_pushinteger(L, (lua_Integer)(time >> 30)) ;
    return 1 ;
}

/// hs.host.volumeInformation([showHidden]) -> table
/// Function
/// Returns a table of information about disk volumes attached to the system
///
/// Parameters:
///  * showHidden - An optional boolean, true to show hidden volumes, false to not show hidden volumes. Defaults to false.
///
/// Returns:
///  * A table of information, where the keys are the paths of disk volumes
///
/// Notes:
///  * The possible keys in the table are:
///   * NSURLVolumeTotalCapacityKey - Size of the volume in bytes
///   * NSURLVolumeAvailableCapacityKey - Available space on the volume in bytes
///   * NSURLVolumeIsAutomountedKey - Boolean indicating if the volume was automounted
///   * NSURLVolumeIsBrowsableKey - Boolean indicating if the volume can be browsed
///   * NSURLVolumeIsEjectableKey - Boolean indicating if the volume should be ejected before its media is removed
///   * NSURLVolumeIsInternalKey - Boolean indicating if the volume is an internal drive or an external drive
///   * NSURLVolumeIsLocalKey - Boolean indicating if the volume is a local or remote drive
///   * NSURLVolumeIsReadOnlyKey - Boolean indicating if the volume is read only
///   * NSURLVolumeIsRemovableKey - Boolean indicating if the volume's media can be physically ejected from the drive (e.g. a DVD)
///   * NSURLVolumeMaximumFileSizeKey - Maximum file size the volume can support, in bytes
///   * NSURLVolumeUUIDStringKey - The UUID of volume's filesystem
///   * NSURLVolumeURLForRemountingKey - For remote volumes, the network URL of the volume
///   * NSURLVolumeLocalizedNameKey - Localized version of the volume's name
///   * NSURLVolumeNameKey - The volume's name
///   * NSURLVolumeLocalizedFormatDescriptionKey - Localized description of the volume
/// * Not all keys will be present for all volumes
/// * The meanings of NSURLVolumeIsEjectableKey and NSURLVolumeIsRemovableKey are not generally useful for determining if a drive is removable in the modern sense (e.g. a USB drive) as much of this terminology dates back to when USB didn't exist and removable drives were things like Floppy/DVD drives. If you're trying to determine if a drive is not fixed into the computer, you may need to use a combination of these keys, but which exact combination you should use, is not consistent across macOS versions.
static int hs_volumeInformation(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSMutableDictionary *volumeInfo = [[NSMutableDictionary alloc] init];

    NSArray *urlResourceKeys = @[NSURLVolumeTotalCapacityKey,
                                 NSURLVolumeAvailableCapacityKey,
                                 NSURLVolumeIsAutomountedKey,
                                 NSURLVolumeIsBrowsableKey,
                                 NSURLVolumeIsEjectableKey,
                                 NSURLVolumeIsInternalKey,
                                 NSURLVolumeIsLocalKey,
                                 NSURLVolumeIsReadOnlyKey,
                                 NSURLVolumeIsRemovableKey,
                                 NSURLVolumeMaximumFileSizeKey,
                                 NSURLVolumeUUIDStringKey,
                                 NSURLVolumeURLForRemountingKey,
                                 NSURLVolumeLocalizedNameKey,
                                 NSURLVolumeNameKey,
                                 NSURLVolumeLocalizedFormatDescriptionKey
                                 ];

    NSVolumeEnumerationOptions options = NSVolumeEnumerationSkipHiddenVolumes;

    if (lua_type(L, 1) == LUA_TBOOLEAN && lua_toboolean(L, 1)) {
        options = (NSVolumeEnumerationOptions)0;
    }

    NSArray *URLs = [fileManager mountedVolumeURLsIncludingResourceValuesForKeys:urlResourceKeys options:options];

    for (NSURL *url in URLs) {
        id       result = [url resourceValuesForKeys:urlResourceKeys error:nil] ;
        NSString *path  = [url path] ;
        if (path && result) [volumeInfo setObject:result forKey:path] ;
    }

    [skin pushNSObject:volumeInfo];

    return 1;
}


/// hs.host.gpuVRAM() -> table
/// Function
/// Returns the model and VRAM size for the installed GPUs.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table whose key-value pairs represent the GPUs for the current system.  Each key is a string contining the name for an installed GPU and its value is the GPU's VRAM size in MB.  If the VRAM size cannot be determined for a specific GPU, its value will be -1.0.
///
/// Notes:
///  * If your GPU reports -1.0 as the memory size, please submit an issue to the Hammerspoon github repository and include any information that you can which may be relevant, such as: Macintosh model, macOS version, is the GPU built in or a third party expansion card, the GPU model and VRAM as best you can determine (see the System Information application in the Utilities folder and look at the Graphics/Display section) and anything else that you think might be important.
static int hs_vramSize(lua_State *L) {
    io_iterator_t Iterator;
    kern_return_t err = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching("IOPCIDevice"), &Iterator);
    if (err != KERN_SUCCESS) {
        return luaL_error(L, "IOServiceGetMatchingServices failed: %u\n", err);
    }

    lua_newtable(L) ;

    for (io_service_t Device; IOIteratorIsValid(Iterator) && (Device = IOIteratorNext(Iterator)); IOObjectRelease(Device)) {
        CFStringRef Name = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("IOName"), kCFAllocatorDefault, kNilOptions);
        if (Name) {
            if (CFStringCompare(Name, CFSTR("display"), (CFStringCompareFlags)0) == kCFCompareEqualTo) {
                CFDataRef Model = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("model"), kCFAllocatorDefault, kNilOptions);
                if (Model) {
                    _Bool ValueInBytes = TRUE;
                    CFTypeRef VRAMSize = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("VRAM,totalsize"), kCFAllocatorDefault, kIORegistryIterateRecursively); //As it could be in a child
                    if (!VRAMSize) {
                        ValueInBytes = FALSE;
                        VRAMSize = IORegistryEntrySearchCFProperty(Device, kIOServicePlane, CFSTR("VRAM,totalMB"), kCFAllocatorDefault, kIORegistryIterateRecursively); //As it could be in a child
                    }

                    if (VRAMSize) {
                        mach_vm_size_t Size = 0;
                        CFTypeID Type = CFGetTypeID(VRAMSize);
                        if (Type == CFDataGetTypeID()) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcast-align"
                            Size = (CFDataGetLength(VRAMSize) == sizeof(uint32_t) ? (mach_vm_size_t)*(const uint32_t*)CFDataGetBytePtr(VRAMSize) : *(const uint64_t*)CFDataGetBytePtr(VRAMSize));
#pragma clang diagnostic pop

                        } else if (Type == CFNumberGetTypeID()) {
                            CFNumberGetValue(VRAMSize, kCFNumberSInt64Type, &Size);
                        }

                        if (ValueInBytes) Size >>= 20;

                        lua_pushnumber(L, Size) ;
                        CFRelease(VRAMSize);
                    } else {
                        lua_pushnumber(L, -1) ;
                    }

                    lua_setfield(L, -2, (const char *)CFDataGetBytePtr(Model)) ;
                    CFRelease(Model);
                }
            }

            CFRelease(Name);
        }
    }

    return 1;
}

static const luaL_Reg hostlib[] = {
    {"addresses",                    hostAddresses},
    {"names",                        hostNames},
    {"localizedName",                hostLocalizedName},
    {"vmStat",                       hs_vmstat},
    {"cpuUsageTicks",                hs_cpuUsageTicks},
    {"operatingSystemVersion",       hs_operatingSystemVersion},
    {"operatingSystemVersionString", hs_operatingSystemVersionString},
    {"thermalState",                 hs_thermalStateString},
    {"interfaceStyle",               hs_interfaceStyle},
    {"uuid",                         hs_uuid},
    {"globallyUniqueString",         hs_globallyUniqueString},
    {"volumeInformation",            hs_volumeInformation},
    {"idleTime",                     hs_idleTime},
    {"gpuVRAM",                      hs_vramSize},

    {NULL, NULL}
};

int luaopen_hs_libhost(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    [skin registerLibrary:"hs.host" functions:hostlib metaFunctions:nil];

    return 1;
}
