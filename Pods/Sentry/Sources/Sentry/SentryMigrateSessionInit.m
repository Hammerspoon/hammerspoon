#import <Foundation/Foundation.h>

#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryLog.h"
#import "SentryMigrateSessionInit.h"
#import "SentrySerialization.h"
#import "SentrySession+Private.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMigrateSessionInit

+ (void)migrateSessionInit:(NSString *)envelopeFilePath
          envelopesDirPath:(NSString *)envelopesDirPath
         envelopeFilePaths:(NSArray<NSString *> *)envelopeFilePaths;
{
    NSData *envelopeData = [[NSFileManager defaultManager] contentsAtPath:envelopeFilePath];
    SentryEnvelope *envelope = [SentrySerialization envelopeWithData:envelopeData];
    if (nil == envelope) {
        return;
    }

    for (SentryEnvelopeItem *item in envelope.items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeSession]) {
            SentrySession *session = [SentrySerialization sessionWithData:item.data];
            if (nil != session && [session.flagInit boolValue]) {
                [self setInitFlagOnNextEnvelopeWithSameSessionId:session
                                                envelopesDirPath:envelopesDirPath
                                               envelopeFilePaths:envelopeFilePaths];
            }
        }
    }
}

+ (void)setInitFlagOnNextEnvelopeWithSameSessionId:(SentrySession *)session
                                  envelopesDirPath:(NSString *)envelopesDirPath
                                 envelopeFilePaths:(NSArray<NSString *> *)envelopeFilePaths
{
    NSFileManager *fileManager = [NSFileManager defaultManager];

    for (NSString *envelopeFilePath in envelopeFilePaths) {
        NSString *envelopePath = [envelopesDirPath stringByAppendingPathComponent:envelopeFilePath];
        NSData *envelopeData = [fileManager contentsAtPath:envelopePath];

        // Some error occured while getting the envelopeData
        if (nil == envelopeData) {
            continue;
        }

        SentryEnvelope *envelope = [SentrySerialization envelopeWithData:envelopeData];

        if (nil != envelope) {
            BOOL didSetInitFlag = [self setInitFlagIfContainsSameSessionId:session.sessionId
                                                                  envelope:envelope
                                                          envelopeFilePath:envelopePath];

            if (didSetInitFlag) {
                break;
            }
        }
    }
}

+ (BOOL)setInitFlagIfContainsSameSessionId:(NSUUID *)sessionId
                                  envelope:(SentryEnvelope *)envelope
                          envelopeFilePath:(NSString *)envelopeFilePath
{
    for (SentryEnvelopeItem *item in envelope.items) {
        if ([item.header.type isEqualToString:SentryEnvelopeItemTypeSession]) {
            SentrySession *localSession = [SentrySerialization sessionWithData:item.data];

            if (nil != localSession && [localSession.sessionId isEqual:sessionId]) {
                [localSession setFlagInit];

                [self storeSessionInit:envelope session:localSession path:envelopeFilePath];
                return YES;
            }
        }
    }

    return NO;
}

+ (void)storeSessionInit:(SentryEnvelope *)originalEnvelope
                 session:(SentrySession *)session
                    path:(NSString *)envelopeFilePath
{
    NSArray<SentryEnvelopeItem *> *envelopeItemsWithUpdatedSession =
        [self replaceSessionEnvelopeItem:session onEnvelope:originalEnvelope];
    SentryEnvelope *envelopeWithInitFlag =
        [[SentryEnvelope alloc] initWithHeader:originalEnvelope.header
                                         items:envelopeItemsWithUpdatedSession];

    NSError *error;
    NSData *envelopeWithInitFlagData = [SentrySerialization dataWithEnvelope:envelopeWithInitFlag
                                                                       error:&error];
    [envelopeWithInitFlagData writeToFile:envelopeFilePath
                                  options:NSDataWritingAtomic
                                    error:&error];

    if (nil != error) {
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"Could not migrate session init, because "
                                                      @"storing the updated envelope failed: %@",
                                     error.description]
                  andLevel:kSentryLogLevelError];
    }
}

+ (NSArray<SentryEnvelopeItem *> *)replaceSessionEnvelopeItem:(SentrySession *)session
                                                   onEnvelope:(SentryEnvelope *)envelope
{
    NSPredicate *noSessionEnvelopeItems =
        [NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
            SentryEnvelopeItem *item = object;
            return ![item.header.type isEqualToString:SentryEnvelopeItemTypeSession];
        }];
    NSMutableArray<SentryEnvelopeItem *> *itemsWithoutSession
        = (NSMutableArray<SentryEnvelopeItem *> *)[[envelope.items
            filteredArrayUsingPredicate:noSessionEnvelopeItems] mutableCopy];

    SentryEnvelopeItem *sessionEnvelopeItem = [[SentryEnvelopeItem alloc] initWithSession:session];
    [itemsWithoutSession addObject:sessionEnvelopeItem];
    return itemsWithoutSession;
}

@end

NS_ASSUME_NONNULL_END
