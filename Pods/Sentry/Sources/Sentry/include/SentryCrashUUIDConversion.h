#ifndef SENTRY_SENTRYCRASHUUIDCONVERSION_H
#define SENTRY_SENTRYCRASHUUIDCONVERSION_H

#ifdef __cplusplus
extern "C" {
#endif

/** Converts SentryCrashBinaryImage.uuid to a human readable 36 charactacters long hex
 * representation.
 *
 * @param src The pointer to an UUID
 *
 * @param dst A buffer with the length of 37 to hold the human readable UUID.
 *
 */
void sentrycrashdl_convertBinaryImageUUID(const unsigned char *src, char *dst);

#ifdef __cplusplus
}
#endif

#endif // SENTRY_SENTRYCRASHUUIDCONVERSION_H
