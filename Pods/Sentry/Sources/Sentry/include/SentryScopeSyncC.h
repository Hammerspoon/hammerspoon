#ifndef SentryScopeSyncC_h
#define SentryScopeSyncC_h

typedef struct {
    char *user;
    char *dist;
    char *context;
    char *environment;
    char *tags;
    char *extras;
    char *fingerprint;
    char *level;
    char **breadcrumbs; // dynamic array of char arrays
    long maxCrumbs;
    long currentCrumb;
} SentryCrashScope;

SentryCrashScope *sentrycrash_scopesync_getScope(void);

/**
 * Needs to be called before adding or clearing breadcrumbs to initialize the storage of the
 * breadcrumbs. Calling this method clears all breadcrumbs.
 */
void sentrycrash_scopesync_configureBreadcrumbs(long maxBreadcrumbs);

void sentrycrash_scopesync_setUser(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setDist(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setContext(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setEnvironment(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setTags(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setExtras(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setFingerprint(const char *const jsonEncodedCString);

void sentrycrash_scopesync_setLevel(const char *const jsonEncodedCString);

void sentrycrash_scopesync_addBreadcrumb(const char *const jsonEncodedCString);

void sentrycrash_scopesync_clearBreadcrumbs(void);

void sentrycrash_scopesync_clear(void);

/**
 * Only needed for testing. Clears the scope, but also sets everything to NULL.
 */
void sentrycrash_scopesync_reset(void);

#endif /* SentryScopeSyncC_h */
