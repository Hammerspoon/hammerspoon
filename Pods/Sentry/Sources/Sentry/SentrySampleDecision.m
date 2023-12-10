#import "SentrySampleDecision.h"

NSString *const kSentrySampleDecisionNameUndecided = @"undecided";
NSString *const kSentrySampleDecisionNameYes = @"true";
NSString *const kSentrySampleDecisionNameNo = @"false";

NSString *
nameForSentrySampleDecision(SentrySampleDecision decision)
{
    switch (decision) {
    case kSentrySampleDecisionUndecided:
        return kSentrySampleDecisionNameUndecided;
    case kSentrySampleDecisionYes:
        return kSentrySampleDecisionNameYes;
    case kSentrySampleDecisionNo:
        return kSentrySampleDecisionNameNo;
    }
}
