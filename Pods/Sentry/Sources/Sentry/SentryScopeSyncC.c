#include "SentryScopeSyncC.h"
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 9

static SentryCrashScope scope = { 0 };

SentryCrashScope *
sentrycrash_scopesync_getScope(void)
{
    return &scope;
}

static void
setField(const char *const newJSONCodedCString, char **field)
{
    char *localField = *field;
    *field = NULL;
    if (localField != NULL) {
        free((void *)localField);
    }

    if (newJSONCodedCString != NULL) {
        *field = strdup(newJSONCodedCString);
    }
}

void
sentrycrash_scopesync_setUser(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.user);
}

void
sentrycrash_scopesync_setDist(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.dist);
}

void
sentrycrash_scopesync_setContext(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.context);
}

void
sentrycrash_scopesync_setEnvironment(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.environment);
}

void
sentrycrash_scopesync_setTags(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.tags);
}

void
sentrycrash_scopesync_setExtras(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.extras);
}

void
sentrycrash_scopesync_setFingerprint(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.fingerprint);
}

void
sentrycrash_scopesync_setLevel(const char *const jsonEncodedCString)
{
    setField(jsonEncodedCString, &scope.level);
}

void
sentrycrash_scopesync_addBreadcrumb(const char *const jsonEncodedCString)
{
    if (!scope.breadcrumbs || scope.maxCrumbs < 1) {
        return;
    }

    setField(jsonEncodedCString, &scope.breadcrumbs[scope.currentCrumb]);
    // Ring buffer
    scope.currentCrumb = (scope.currentCrumb + 1) % scope.maxCrumbs;
}

void
sentrycrash_scopesync_clearBreadcrumbs(void)
{
    if (!scope.breadcrumbs || scope.maxCrumbs < 1) {
        return;
    }

    for (int i = 0; i < scope.maxCrumbs; i++) {
        setField(NULL, &scope.breadcrumbs[i]);
    }

    scope.currentCrumb = 0;
}

void
sentrycrash_scopesync_configureBreadcrumbs(long maxBreadcrumbs)
{
    scope.maxCrumbs = maxBreadcrumbs;
    size_t size = sizeof(char *) * scope.maxCrumbs;
    scope.currentCrumb = 0;
    if (scope.breadcrumbs) {
        free((void *)scope.breadcrumbs);
    }
    scope.breadcrumbs = malloc(size);
    memset(scope.breadcrumbs, 0, size);
}

void
sentrycrash_scopesync_clear(void)
{
    sentrycrash_scopesync_setUser(NULL);
    sentrycrash_scopesync_setDist(NULL);
    sentrycrash_scopesync_setContext(NULL);
    sentrycrash_scopesync_setEnvironment(NULL);
    sentrycrash_scopesync_setTags(NULL);
    sentrycrash_scopesync_setExtras(NULL);
    sentrycrash_scopesync_setFingerprint(NULL);
    sentrycrash_scopesync_setLevel(NULL);
    sentrycrash_scopesync_clearBreadcrumbs();
}

void
sentrycrash_scopesync_reset(void)
{
    sentrycrash_scopesync_clear();
    scope.breadcrumbs = NULL;
}
