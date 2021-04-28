#import <Foundation/Foundation.h>

/**
 * Describes the status of the Span/Transaction.
 */
typedef NS_ENUM(NSUInteger, SentrySpanStatus) {
    /**
     * An undefined status.
     */
    kSentrySpanStatusUndefined,

    /**
     * Not an error, returned on success.
     */
    kSentrySpanStatusOk,

    /**
     * The deadline expired before the operation could succeed.
     */
    kSentrySpanStatusDeadlineExceeded,

    /**
     * The requester doesn't have valid authentication credentials for the operation.
     */
    kSentrySpanStatusUnauthenticated,

    /**
     * The caller doesn't have permission to execute the specified operation.
     */
    kSentrySpanStatusPermissionDenied,

    /**
     * Content was not found or request was denied for an entire class of users.
     */
    kSentrySpanStatusNotFound,

    /**
     * The resource has been exhausted e.g. per-user quota exhausted, file system out of space.
     */
    kSentrySpanStatusResourceExhausted,

    /**
     * The client specified an invalid argument.
     */
    kSentrySpanStatusInvalidArgument,

    /**
     * 501 Not Implemented.
     */
    kSentrySpanStatusUnimplemented,

    /**
     * The operation is not implemented or is not supported/enabled for this operation.
     */
    kSentrySpanStatusUnavailable,

    /**
     * Some invariants expected by the underlying system have been broken. This code is reserved for
     * serious errors.
     */
    kSentrySpanStatusInternalError,

    /**
     * An unknown error raised by APIs that don't return enough error information.
     */
    kSentrySpanStatusUnknownError,

    /**
     * The operation was cancelled, typically by the caller.
     */
    kSentrySpanStatusCancelled,

    /**
     * The entity attempted to be created already exists.
     */
    kSentrySpanStatusAlreadyExists,

    /**
     * The client shouldn't retry until the system state has been explicitly handled.
     */
    kSentrySpanStatusFailedPrecondition,

    /**
     * The operation was aborted.
     */
    kSentrySpanStatusAborted,

    /**
     * The operation was attempted past the valid range e.g. seeking past the end of a file.
     */
    kSentrySpanStatusOutOfRange,

    /**
     * Unrecoverable data loss or corruption.
     */
    kSentrySpanStatusDataLoss,
};

static NSString *_Nonnull const SentrySpanStatusNames[]
    = { @"undefined", @"ok", @"deadline_exceeded", @"unauthenticated", @"permission_denied",
          @"not_found", @"resource_exhausted", @"invalid_argument", @"unimplemented",
          @"unavailable", @"internal_error", @"unknown_error", @"cancelled", @"already_exists",
          @"failed_precondition", @"aborted", @"out_of_range", @"data_loss" };
