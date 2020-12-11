#include "SentryCrashUUIDConversion.h"

void
sentrycrashdl_convertBinaryImageUUID(const unsigned char *src, char *dst)
{
    const char g_hexNybbles[]
        = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' };

    for (int i = 0; i < 4; i++) {
        *dst++ = g_hexNybbles[(*src >> 4) & 15];
        *dst++ = g_hexNybbles[(*src++) & 15];
    }
    *dst++ = '-';
    for (int i = 0; i < 2; i++) {
        *dst++ = g_hexNybbles[(*src >> 4) & 15];
        *dst++ = g_hexNybbles[(*src++) & 15];
    }
    *dst++ = '-';
    for (int i = 0; i < 2; i++) {
        *dst++ = g_hexNybbles[(*src >> 4) & 15];
        *dst++ = g_hexNybbles[(*src++) & 15];
    }
    *dst++ = '-';
    for (int i = 0; i < 2; i++) {
        *dst++ = g_hexNybbles[(*src >> 4) & 15];
        *dst++ = g_hexNybbles[(*src++) & 15];
    }
    *dst++ = '-';
    for (int i = 0; i < 6; i++) {
        *dst++ = g_hexNybbles[(*src >> 4) & 15];
        *dst++ = g_hexNybbles[(*src++) & 15];
    }
    *dst++ = '\0';
}
