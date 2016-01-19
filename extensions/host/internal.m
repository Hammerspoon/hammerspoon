#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <sys/sysctl.h>
#import <sys/types.h>
#import <mach/mach.h>
#import <mach/processor_info.h>
#import <mach/host_info.h>
#import <mach/mach_host.h>
#import <mach/task_info.h>
#import <mach/task.h>

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
    LuaSkin *skin = [LuaSkin shared];
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
        lua_pushinteger(L, (uint64_t) (vm_stat.free_count - vm_stat.speculative_count)) ; lua_setfield(L, -2, "pagesFree") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.active_count))                           ; lua_setfield(L, -2, "pagesActive") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.inactive_count))                         ; lua_setfield(L, -2, "pagesInactive") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.speculative_count))                      ; lua_setfield(L, -2, "pagesSpeculative") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.throttled_count))                        ; lua_setfield(L, -2, "pagesThrottled") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.wire_count))                             ; lua_setfield(L, -2, "pagesWiredDown") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.purgeable_count))                        ; lua_setfield(L, -2, "pagesPurgeable") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.faults))                                 ; lua_setfield(L, -2, "translationFaults") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.cow_faults))                             ; lua_setfield(L, -2, "pagesCopyOnWrite") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.zero_fill_count))                        ; lua_setfield(L, -2, "pagesZeroFilled") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.reactivations))                          ; lua_setfield(L, -2, "pagesReactivated") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.purges))                                 ; lua_setfield(L, -2, "pagesPurged") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.external_page_count))                    ; lua_setfield(L, -2, "fileBackedPages") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.internal_page_count))                    ; lua_setfield(L, -2, "anonymousPages") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.total_uncompressed_pages_in_compressor)) ; lua_setfield(L, -2, "uncompressedPages") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.compressor_page_count))                  ; lua_setfield(L, -2, "pagesUsedByVMCompressor") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.decompressions))                         ; lua_setfield(L, -2, "pagesDecompressed") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.compressions))                           ; lua_setfield(L, -2, "pagesCompressed") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.pageins))                                ; lua_setfield(L, -2, "pageIns") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.pageouts))                               ; lua_setfield(L, -2, "pageOuts") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.swapins))                                ; lua_setfield(L, -2, "swapIns") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.swapouts))                               ; lua_setfield(L, -2, "swapOuts") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.lookups))                                ; lua_setfield(L, -2, "cacheLookups") ;
        lua_pushinteger(L, (uint64_t) (vm_stat.hits))                                   ; lua_setfield(L, -2, "cacheHits") ;
        lua_pushinteger(L, (uint32_t) (pagesize))                                       ; lua_setfield(L, -2, "pageSize") ;
        lua_pushinteger(L, (uint64_t) (memsize))                                        ; lua_setfield(L, -2, "memSize") ;
    return 1 ;
}

/// hs.host.cpuUsage() -> table
/// Function
/// Returns a table containing cpu usage information for the current machine.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following:
///    * A tables, indexed by the core number, for each CPU core with the following keys in each subtable:
///      * user   -- percentage of CPU time occupied by user level processes.
///      * system -- percentage of CPU time occupied by system (kernel) level processes.
///      * nice   -- percentage of CPU time occupied by user level processes with a positive nice value (lower scheduling priority).
///      * active -- For convenience, when you just want the total CPU usage, this is the sum of user, system, and nice.
///      * idle   -- percentage of CPU time spent idle
///    * The key `overall` containing the same keys as described above but based upon the average of all cores combined.
///    * The key `n` containing the number of cores detected.
///
/// Notes:
///  * The subtables for each core and `overall` have a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.host.cpuUsage()[#]` where # is the core you are interested in or the string "overall".
///  * Adapted primarily from code found at http://stackoverflow.com/questions/6785069/get-cpu-percent-usage
static int hs_cpuInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
        float overallInUser   = 0.0 ;
        float overallInSystem = 0.0 ;
        float overallInNice   = 0.0 ;
        float overallInIdle   = 0.0 ;
        float overallInUse    = 0.0 ;
        float overallTotal    = 0.0 ;
        lua_newtable(L) ;
        for(unsigned i = 0U; i < numCPUs; ++i) {
            float inUser   = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] ;    overallInUser   += inUser ;
            float inSystem = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] ;  overallInSystem += inSystem ;
            float inNice   = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE] ;    overallInNice   += inNice ;
            float inIdle   = cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] ;    overallInIdle   += inIdle ;
            float inUse    = inUser + inSystem + inNice ;                       overallInUse    += inUse ;
            float total    = inUse + inIdle ;                                   overallTotal    += total ;
            lua_newtable(L) ;
                lua_pushnumber(L, (  inUser / total) * 100) ; lua_setfield(L, -2, "user") ;
                lua_pushnumber(L, (inSystem / total) * 100) ; lua_setfield(L, -2, "system") ;
                lua_pushnumber(L, (  inNice / total) * 100) ; lua_setfield(L, -2, "nice") ;
                lua_pushnumber(L, (   inUse / total) * 100) ; lua_setfield(L, -2, "active") ;
                lua_pushnumber(L, (  inIdle / total) * 100) ; lua_setfield(L, -2, "idle") ;
            lua_rawseti(L, -2, luaL_len(L, -2) + 1);  // Insert this table at end of result table
        }
        lua_newtable(L) ;
            lua_pushnumber(L, (  overallInUser / overallTotal) * 100) ; lua_setfield(L, -2, "user") ;
            lua_pushnumber(L, (overallInSystem / overallTotal) * 100) ; lua_setfield(L, -2, "system") ;
            lua_pushnumber(L, (  overallInNice / overallTotal) * 100) ; lua_setfield(L, -2, "nice") ;
            lua_pushnumber(L, (   overallInUse / overallTotal) * 100) ; lua_setfield(L, -2, "active") ;
            lua_pushnumber(L, (  overallInIdle / overallTotal) * 100) ; lua_setfield(L, -2, "idle") ;
        lua_setfield(L, -2, "overall") ;
    } else {
        char errStr[255] ;
        snprintf(errStr, 255, "Error getting CPU Usage data: %s", mach_error_string(err)) ;
        [skin logError:[NSString stringWithFormat:@"hs.host.cpuUsage() error: %s", errStr]];
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
///   * NSURLVolumeIsEjectableKey - Boolean indicating if the volume can be ejected
///   * NSURLVolumeIsInternalKey - Boolean indicating if the volume is an internal drive or an external drive
///   * NSURLVolumeIsLocalKey - Boolean indicating if the volume is a local or remote drive
///   * NSURLVolumeIsReadOnlyKey - Boolean indicating if the volume is read only
///   * NSURLVolumeIsRemovableKey - Boolean indicating if the volume is removable
///   * NSURLVolumeMaximumFileSizeKey - Maximum file size the volume can support, in bytes
///   * NSURLVolumeUUIDStringKey - The UUID of volume's filesystem
///   * NSURLVolumeURLForRemountingKey - For remote volumes, the network URL of the volume
///   * NSURLVolumeLocalizedNameKey - Localized version of the volume's name
///   * NSURLVolumeNameKey - The volume's name
///   * NSURLVolumeLocalizedFormatDescriptionKey - Localized description of the volume
/// * Not all keys will be present for all volumes
static int hs_volumeInformation(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
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
        options = 0;
    }

    NSArray *URLs = [fileManager mountedVolumeURLsIncludingResourceValuesForKeys:urlResourceKeys options:options];

    for (NSURL *url in URLs) {
        id result = [url resourceValuesForKeys:urlResourceKeys error:nil] ;
        if (result) [volumeInfo setObject:result forKey:[url path]];
        [volumeInfo setObject:[url resourceValuesForKeys:urlResourceKeys error:nil] forKey:[url path]];
    }

    [skin pushNSObject:volumeInfo];

    return 1;
}

static const luaL_Reg hostlib[] = {
    {"addresses",                    hostAddresses},
    {"names",                        hostNames},
    {"localizedName",                hostLocalizedName},
    {"vmStat",                       hs_vmstat},
    {"cpuUsage",                     hs_cpuInfo},
    {"operatingSystemVersion",       hs_operatingSystemVersion},
    {"operatingSystemVersionString", hs_operatingSystemVersionString},
    {"interfaceStyle",               hs_interfaceStyle},
    {"uuid",                         hs_uuid},
    {"globallyUniqueString",         hs_globallyUniqueString},
    {"volumeInformation",            hs_volumeInformation},

    {NULL, NULL}
};

int luaopen_hs_host_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];

    [skin registerLibrary:hostlib metaFunctions:nil];

    return 1;
}
