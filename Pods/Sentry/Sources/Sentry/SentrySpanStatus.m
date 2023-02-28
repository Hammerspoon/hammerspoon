#import "SentrySpanStatus.h"

NSString *const kSentrySpanStatusNameUndefined = @"undefined";
NSString *const kSentrySpanStatusNameOk = @"ok";
NSString *const kSentrySpanStatusNameDeadlineExceeded = @"deadline_exceeded";
NSString *const kSentrySpanStatusNameUnauthenticated = @"unauthenticated";
NSString *const kSentrySpanStatusNamePermissionDenied = @"permission_denied";
NSString *const kSentrySpanStatusNameNotFound = @"not_found";
NSString *const kSentrySpanStatusNameResourceExhausted = @"resource_exhausted";
NSString *const kSentrySpanStatusNameInvalidArgument = @"invalid_argument";
NSString *const kSentrySpanStatusNameUnimplemented = @"unimplemented";
NSString *const kSentrySpanStatusNameUnavailable = @"unavailable";
NSString *const kSentrySpanStatusNameInternalError = @"internal_error";
NSString *const kSentrySpanStatusNameUnknownError = @"unknown_error";
NSString *const kSentrySpanStatusNameCancelled = @"cancelled";
NSString *const kSentrySpanStatusNameAlreadyExists = @"already_exists";
NSString *const kSentrySpanStatusNameFailedPrecondition = @"failed_precondition";
NSString *const kSentrySpanStatusNameAborted = @"aborted";
NSString *const kSentrySpanStatusNameOutOfRange = @"out_of_range";
NSString *const kSentrySpanStatusNameDataLoss = @"data_loss";

NSString *
nameForSentrySpanStatus(SentrySpanStatus status)
{
    switch (status) {
    case kSentrySpanStatusUndefined:
        return kSentrySpanStatusNameUndefined;
    case kSentrySpanStatusOk:
        return kSentrySpanStatusNameOk;
    case kSentrySpanStatusDeadlineExceeded:
        return kSentrySpanStatusNameDeadlineExceeded;
    case kSentrySpanStatusUnauthenticated:
        return kSentrySpanStatusNameUnauthenticated;
    case kSentrySpanStatusPermissionDenied:
        return kSentrySpanStatusNamePermissionDenied;
    case kSentrySpanStatusNotFound:
        return kSentrySpanStatusNameNotFound;
    case kSentrySpanStatusResourceExhausted:
        return kSentrySpanStatusNameResourceExhausted;
    case kSentrySpanStatusInvalidArgument:
        return kSentrySpanStatusNameInvalidArgument;
    case kSentrySpanStatusUnimplemented:
        return kSentrySpanStatusNameUnimplemented;
    case kSentrySpanStatusUnavailable:
        return kSentrySpanStatusNameUnavailable;
    case kSentrySpanStatusInternalError:
        return kSentrySpanStatusNameInternalError;
    case kSentrySpanStatusUnknownError:
        return kSentrySpanStatusNameUnknownError;
    case kSentrySpanStatusCancelled:
        return kSentrySpanStatusNameCancelled;
    case kSentrySpanStatusAlreadyExists:
        return kSentrySpanStatusNameAlreadyExists;
    case kSentrySpanStatusFailedPrecondition:
        return kSentrySpanStatusNameFailedPrecondition;
    case kSentrySpanStatusAborted:
        return kSentrySpanStatusNameAborted;
    case kSentrySpanStatusOutOfRange:
        return kSentrySpanStatusNameOutOfRange;
    case kSentrySpanStatusDataLoss:
        return kSentrySpanStatusNameDataLoss;
    }
}
