#include "SentryMachLogging.hpp"

namespace sentry {

const char *
kernelReturnCodeDescription(kern_return_t kr) noexcept
{
    switch (kr) {
    case KERN_SUCCESS:
        return "Success.";
    case KERN_INVALID_ADDRESS:
        return "Specified address is not currently valid.";
    case KERN_PROTECTION_FAILURE:
        return "Specified memory is valid, but does not permit the required forms of access.";
    case KERN_NO_SPACE:
        return "The address range specified is already in use, or no address range of the size "
               "specified could be found.";
    case KERN_INVALID_ARGUMENT:
        return "The function requested was not applicable to this type of argument, or an "
               "argument is invalid.";
    case KERN_FAILURE:
        return "The function could not be performed.";
    case KERN_RESOURCE_SHORTAGE:
        return "A system resource could not be allocated to fulfill this request.";
    case KERN_NOT_RECEIVER:
        return "The task in question does not hold receive rights for the port argument.";
    case KERN_NO_ACCESS:
        return "Bogus access restriction.";
    case KERN_MEMORY_FAILURE:
        return "During a page fault, the target address refers to a memory object that has "
               "been destroyed.";
    case KERN_MEMORY_ERROR:
        return "During a page fault, the memory object indicated that the data could not be "
               "returned.";
    case KERN_ALREADY_IN_SET:
        return "The receive right is already a member of the portset.";
    case KERN_NOT_IN_SET:
        return "The receive right is not a member of a port set.";
    case KERN_NAME_EXISTS:
        return "The name already denotes a right in the task.";
    case KERN_ABORTED:
        return "The operation was aborted.";
    case KERN_INVALID_NAME:
        return "The name doesn't denote a right in the task.";
    case KERN_INVALID_TASK:
        return "Target task isn't an active task.";
    case KERN_INVALID_RIGHT:
        return "The name denotes a right, but not an appropriate right.";
    case KERN_INVALID_VALUE:
        return "A blatant range error.";
    case KERN_UREFS_OVERFLOW:
        return "Operation would overflow limit on user-references.";
    case KERN_INVALID_CAPABILITY:
        return "The supplied (port) capability is improper.";
    case KERN_RIGHT_EXISTS:
        return "The task already has send or receive rights for the port under another name.";
    case KERN_INVALID_HOST:
        return "Target host isn't actually a host.";
    case KERN_MEMORY_PRESENT:
        return "An attempt was made to supply \"precious\" data for memory that is already "
               "present in a memory object.";
    case KERN_MEMORY_DATA_MOVED:
        return "See code documentation for KERN_MEMORY_DATA_MOVED";
    case KERN_MEMORY_RESTART_COPY:
        return "See code documentation for KERN_MEMORY_RESTART_COPY";
    case KERN_INVALID_PROCESSOR_SET:
        return "An argument applied to assert processor set privilege was not a processor set "
               "control port.";
    case KERN_POLICY_LIMIT:
        return "The specified scheduling attributes exceed the thread's limits.";
    case KERN_INVALID_POLICY:
        return "The specified scheduling policy is not currently enabled for the processor "
               "set.";
    case KERN_INVALID_OBJECT:
        return "The external memory manager failed to initialize the memory object.";
    case KERN_ALREADY_WAITING:
        return "A thread is attempting to wait for an event for which there is already a "
               "waiting thread.";
    case KERN_DEFAULT_SET:
        return "An attempt was made to destroy the default processor set";
    case KERN_EXCEPTION_PROTECTED:
        return "An attempt was made to fetch an exception port that is protected, or to abort "
               "a thread while processing a protected exception.";
    case KERN_INVALID_LEDGER:
        return "A ledger was required but not supplied.";
    case KERN_INVALID_MEMORY_CONTROL:
        return "The port was not a memory cache control port.";
    case KERN_INVALID_SECURITY:
        return "An argument supplied to assert security privilege was not a host security "
               "port.";
    case KERN_NOT_DEPRESSED:
        return "thread_depress_abort was called on a thread which was not currently depressed.";
    case KERN_TERMINATED:
        return "Object has been terminated and is no longer available";
    case KERN_LOCK_SET_DESTROYED:
        return "Lock set has been destroyed and is no longer available.";
    case KERN_LOCK_UNSTABLE:
        return "The thread holding the lock terminated before releasing";
    case KERN_LOCK_OWNED:
        return "The lock is already owned by another thread";
    case KERN_LOCK_OWNED_SELF:
        return "The lock is already owned by the calling thread";
    case KERN_SEMAPHORE_DESTROYED:
        return "Semaphore has been destroyed and is no longer available.";
    case KERN_RPC_SERVER_TERMINATED:
        return "Return from RPC indicating the target server was terminated before it "
               "successfully replied.";
    case KERN_RPC_TERMINATE_ORPHAN:
        return "Terminate an orphaned activation.";
    case KERN_RPC_CONTINUE_ORPHAN:
        return "Allow an orphaned activation to continue executing.";
    case KERN_NOT_SUPPORTED:
        return "Empty thread activation (No thread linked to it)";
    case KERN_NODE_DOWN:
        return "Remote node down or inaccessible.";
    case KERN_NOT_WAITING:
        return "A signalled thread was not actually waiting.";
    case KERN_OPERATION_TIMED_OUT:
        return "Some thread-oriented operation (semaphore_wait) timed out";
    case KERN_CODESIGN_ERROR:
        return "During a page fault, indicates that the page was rejected as a result of a "
               "signature check.";
    case KERN_POLICY_STATIC:
        return "The requested property cannot be changed at this time.";
    case KERN_INSUFFICIENT_BUFFER_SIZE:
        return "The provided buffer is of insufficient size for the requested data.";
    default:
        return "Unknown error.";
    }
}

const char *
machMessageReturnCodeDescription(mach_msg_return_t mr) noexcept
{
    switch (mr) {
    case MACH_MSG_SUCCESS:
        return "Success.";
    case MACH_SEND_NO_BUFFER:
        return "A resource shortage prevented the kernel from allocating a message buffer.";
    case MACH_SEND_INVALID_DATA:
        return "The supplied message buffer was not readable.";
    case MACH_SEND_INVALID_HEADER:
        return "The msgh_bits value was invalid.";
    case MACH_SEND_INVALID_DEST:
        return "The msgh_remote_port value was invalid.";
    case MACH_SEND_INVALID_NOTIFY:
        return "When using MACH_SEND_CANCEL, the notify argument did not denote a valid "
               "receive right.";
    case MACH_SEND_INVALID_REPLY:
        return "The msgh_local_port value was invalid.";
    case MACH_SEND_INVALID_TRAILER:
        return "The trailer to be sent does not correspond to the current kernel format, or "
               "the sending task does not have the privilege to supply the message attributes.";
    case MACH_SEND_INVALID_MEMORY:
        return "The message body specified out-of-line data that was not readable.";
    case MACH_SEND_INVALID_RIGHT:
        return "The message body specified a port right which the caller didn't possess.";
    case MACH_SEND_INVALID_TYPE:
        return "A kernel processed descriptor was invalid.";
    case MACH_SEND_MSG_TOO_SMALL:
        return "The last data item in the message ran over the end of the message.";
    case MACH_SEND_TIMED_OUT:
        return "The timeout interval expired.";
    case MACH_SEND_INTERRUPTED:
        return "A software interrupt occurred.";
    case MACH_RCV_INVALID_NAME:
        return "The specified receive_name was invalid.";
    case MACH_RCV_IN_SET:
        return "The specified port was a member of a port set.";
    case MACH_RCV_TIMED_OUT:
        return "The timeout interval expired.";
    case MACH_RCV_INTERRUPTED:
        return "A software interrupt occurred.";
    case MACH_RCV_PORT_DIED:
        return "The caller lost the rights specified by receive_name.";
    case MACH_RCV_PORT_CHANGED:
        return "receive_name specified a receive right which was moved into a port set during "
               "the call.";
    case MACH_RCV_TOO_LARGE:
        return "When using MACH_RCV_LARGE, the message was larger than receive_limit. The "
               "message is left queued, and its actual size is returned in the message "
               "header/message body.";
    case MACH_RCV_INVALID_TRAILER:
        return "The trailer type desired, or the number of trailer elements desired, is not "
               "supported by the kernel.";
    case MACH_RCV_HEADER_ERROR:
        return "A resource shortage prevented the reception of the port rights in the message "
               "header.";
    case MACH_RCV_INVALID_NOTIFY:
        return "When using MACH_RCV_NOTIFY, the notify argument did not denote a valid receive "
               "right.";
    case MACH_RCV_INVALID_DATA:
        return "The specified message buffer was not writable.";
    case MACH_RCV_SCATTER_SMALL:
        return "When not using MACH_RCV_LARGE with MACH_RCV_OVERWRITE, one or more scatter "
               "list descriptors specified an overwrite region smaller than the corresponding "
               "incoming region. The message was de-queued and destroyed.";
    case MACH_RCV_INVALID_TYPE:
        return "When using MACH_RCV_OVERWRITE, one or more scatter list descriptors did not "
               "have the type matching the corresponding incoming message descriptor or had an "
               "invalid copy (disposition) field.";
    case MACH_RCV_BODY_ERROR:
        return "A resource shortage prevented the reception of a port right or out-of- line "
               "memory region in the message body.";
    default:
        return "Unknown error.";
    }
}

} // namespace sentry
