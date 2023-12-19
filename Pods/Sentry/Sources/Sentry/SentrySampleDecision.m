#import "SentrySampleDecision.h"

NSNumber *
valueForSentrySampleDecision(SentrySampleDecision decision)
{
    switch (decision) {
    case kSentrySampleDecisionUndecided:
        return nil;
    case kSentrySampleDecisionYes:
        return @YES;
    case kSentrySampleDecisionNo:
        return @NO;
    }
}
