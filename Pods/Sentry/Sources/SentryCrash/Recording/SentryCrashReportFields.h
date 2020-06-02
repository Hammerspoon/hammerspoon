//
//  SentryCrashReportFields.h
//
//  Created by Karl Stenerud on 2012-10-07.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//


#ifndef HDR_SentryCrashReportFields_h
#define HDR_SentryCrashReportFields_h


#pragma mark - Report Types -

#define SentryCrashReportType_Minimal          "minimal"
#define SentryCrashReportType_Standard         "standard"
#define SentryCrashReportType_Custom           "custom"


#pragma mark - Memory Types -

#define SentryCrashMemType_Block               "objc_block"
#define SentryCrashMemType_Class               "objc_class"
#define SentryCrashMemType_NullPointer         "null_pointer"
#define SentryCrashMemType_Object              "objc_object"
#define SentryCrashMemType_String              "string"
#define SentryCrashMemType_Unknown             "unknown"


#pragma mark - Exception Types -

#define SentryCrashExcType_CPPException        "cpp_exception"
#define SentryCrashExcType_Deadlock            "deadlock"
#define SentryCrashExcType_Mach                "mach"
#define SentryCrashExcType_NSException         "nsexception"
#define SentryCrashExcType_Signal              "signal"
#define SentryCrashExcType_User                "user"


#pragma mark - Common -

#define SentryCrashField_Address               "address"
#define SentryCrashField_Contents              "contents"
#define SentryCrashField_Exception             "exception"
#define SentryCrashField_FirstObject           "first_object"
#define SentryCrashField_Index                 "index"
#define SentryCrashField_Ivars                 "ivars"
#define SentryCrashField_Language              "language"
#define SentryCrashField_Name                  "name"
#define SentryCrashField_UserInfo              "userInfo"
#define SentryCrashField_ReferencedObject      "referenced_object"
#define SentryCrashField_Type                  "type"
#define SentryCrashField_UUID                  "uuid"
#define SentryCrashField_Value                 "value"

#define SentryCrashField_Error                 "error"
#define SentryCrashField_JSONData              "json_data"


#pragma mark - Notable Address -

#define SentryCrashField_Class                 "class"
#define SentryCrashField_LastDeallocObject     "last_deallocated_obj"


#pragma mark - Backtrace -

#define SentryCrashField_InstructionAddr       "instruction_addr"
#define SentryCrashField_LineOfCode            "line_of_code"
#define SentryCrashField_ObjectAddr            "object_addr"
#define SentryCrashField_ObjectName            "object_name"
#define SentryCrashField_SymbolAddr            "symbol_addr"
#define SentryCrashField_SymbolName            "symbol_name"


#pragma mark - Stack Dump -

#define SentryCrashField_DumpEnd               "dump_end"
#define SentryCrashField_DumpStart             "dump_start"
#define SentryCrashField_GrowDirection         "grow_direction"
#define SentryCrashField_Overflow              "overflow"
#define SentryCrashField_StackPtr              "stack_pointer"


#pragma mark - Thread Dump -

#define SentryCrashField_Backtrace             "backtrace"
#define SentryCrashField_Basic                 "basic"
#define SentryCrashField_Crashed               "crashed"
#define SentryCrashField_CurrentThread         "current_thread"
#define SentryCrashField_DispatchQueue         "dispatch_queue"
#define SentryCrashField_NotableAddresses      "notable_addresses"
#define SentryCrashField_Registers             "registers"
#define SentryCrashField_Skipped               "skipped"
#define SentryCrashField_Stack                 "stack"


#pragma mark - Binary Image -

#define SentryCrashField_CPUSubType            "cpu_subtype"
#define SentryCrashField_CPUType               "cpu_type"
#define SentryCrashField_ImageAddress          "image_addr"
#define SentryCrashField_ImageVmAddress        "image_vmaddr"
#define SentryCrashField_ImageSize             "image_size"
#define SentryCrashField_ImageMajorVersion     "major_version"
#define SentryCrashField_ImageMinorVersion     "minor_version"
#define SentryCrashField_ImageRevisionVersion  "revision_version"


#pragma mark - Memory -

#define SentryCrashField_Free                  "free"
#define SentryCrashField_Usable                "usable"


#pragma mark - Error -

#define SentryCrashField_Backtrace             "backtrace"
#define SentryCrashField_Code                  "code"
#define SentryCrashField_CodeName              "code_name"
#define SentryCrashField_CPPException          "cpp_exception"
#define SentryCrashField_ExceptionName         "exception_name"
#define SentryCrashField_Mach                  "mach"
#define SentryCrashField_NSException           "nsexception"
#define SentryCrashField_Reason                "reason"
#define SentryCrashField_Signal                "signal"
#define SentryCrashField_Subcode               "subcode"
#define SentryCrashField_UserReported          "user_reported"


#pragma mark - Process State -

#define SentryCrashField_LastDeallocedNSException "last_dealloced_nsexception"
#define SentryCrashField_ProcessState             "process"


#pragma mark - App Stats -

#define SentryCrashField_ActiveTimeSinceCrash  "active_time_since_last_crash"
#define SentryCrashField_ActiveTimeSinceLaunch "active_time_since_launch"
#define SentryCrashField_AppActive             "application_active"
#define SentryCrashField_AppInFG               "application_in_foreground"
#define SentryCrashField_BGTimeSinceCrash      "background_time_since_last_crash"
#define SentryCrashField_BGTimeSinceLaunch     "background_time_since_launch"
#define SentryCrashField_LaunchesSinceCrash    "launches_since_last_crash"
#define SentryCrashField_SessionsSinceCrash    "sessions_since_last_crash"
#define SentryCrashField_SessionsSinceLaunch   "sessions_since_launch"


#pragma mark - Report -

#define SentryCrashField_Crash                 "crash"
#define SentryCrashField_Debug                 "debug"
#define SentryCrashField_Diagnosis             "diagnosis"
#define SentryCrashField_ID                    "id"
#define SentryCrashField_ProcessName           "process_name"
#define SentryCrashField_Report                "report"
#define SentryCrashField_Timestamp             "timestamp"
#define SentryCrashField_Version               "version"

#pragma mark Minimal
#define SentryCrashField_CrashedThread         "crashed_thread"

#pragma mark Standard
#define SentryCrashField_AppStats              "application_stats"
#define SentryCrashField_BinaryImages          "binary_images"
#define SentryCrashField_System                "system"
#define SentryCrashField_Memory                "memory"
#define SentryCrashField_Threads               "threads"
#define SentryCrashField_User                  "user"
#define SentryCrashField_ConsoleLog            "console_log"

#pragma mark Incomplete
#define SentryCrashField_Incomplete            "incomplete"
#define SentryCrashField_RecrashReport         "recrash_report"

#pragma mark System
#define SentryCrashField_AppStartTime          "app_start_time"
#define SentryCrashField_AppUUID               "app_uuid"
#define SentryCrashField_BootTime              "boot_time"
#define SentryCrashField_BundleID              "CFBundleIdentifier"
#define SentryCrashField_BundleName            "CFBundleName"
#define SentryCrashField_BundleShortVersion    "CFBundleShortVersionString"
#define SentryCrashField_BundleVersion         "CFBundleVersion"
#define SentryCrashField_CPUArch               "cpu_arch"
#define SentryCrashField_CPUType               "cpu_type"
#define SentryCrashField_CPUSubType            "cpu_subtype"
#define SentryCrashField_BinaryCPUType         "binary_cpu_type"
#define SentryCrashField_BinaryCPUSubType      "binary_cpu_subtype"
#define SentryCrashField_DeviceAppHash         "device_app_hash"
#define SentryCrashField_Executable            "CFBundleExecutable"
#define SentryCrashField_ExecutablePath        "CFBundleExecutablePath"
#define SentryCrashField_Jailbroken            "jailbroken"
#define SentryCrashField_KernelVersion         "kernel_version"
#define SentryCrashField_Machine               "machine"
#define SentryCrashField_Model                 "model"
#define SentryCrashField_OSVersion             "os_version"
#define SentryCrashField_ParentProcessID       "parent_process_id"
#define SentryCrashField_ProcessID             "process_id"
#define SentryCrashField_ProcessName           "process_name"
#define SentryCrashField_Size                  "size"
#define SentryCrashField_Storage               "storage"
#define SentryCrashField_SystemName            "system_name"
#define SentryCrashField_SystemVersion         "system_version"
#define SentryCrashField_TimeZone              "time_zone"
#define SentryCrashField_BuildType             "build_type"

#endif
