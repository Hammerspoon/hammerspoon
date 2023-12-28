#import "SentryDefines.h"

@class SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

/**
 * For proper statistics in release health, we need to make sure we don't send session updates
 * without sending a session init first. In other words, we can't drop a session init. The
 * @c SentryFileManager deletes an envelope once the maximum amount of envelopes is stored. When
 * this happens and the envelope to delete contains a session init we look for the next envelope
 * containing a session update for the same session. If such a session envelope is found we migrate
 * the init flag. If none is found we delete the envelope. We don't migrate other envelope items as
 * events.
 */
@interface SentryMigrateSessionInit : NSObject
SENTRY_NO_INIT

/**
 * Checks if the envelope of the passed file path contains an envelope item with a session init. If
 * it does it iterates over all envelopes and looks for a session with the same session id. If such
 * a session is found the init flag is set to @c YES, the envelope is updated with keeping other
 * envelope items and headers, and the updated envelope is stored to the disk keeping its path.
 * @param envelope The envelope to delete
 * @param envelopesDirPath The path of the directory where the envelopes are stored.
 * @param envelopeFilePaths An array containing the file paths of envelopes to check if they contain
 * a session init.
 * @return @c YES if the function migrated the session init. @c NO if not.
 */
+ (BOOL)migrateSessionInit:(SentryEnvelope *)envelope
          envelopesDirPath:(NSString *)envelopesDirPath
         envelopeFilePaths:(NSArray<NSString *> *)envelopeFilePaths;

@end

NS_ASSUME_NONNULL_END
