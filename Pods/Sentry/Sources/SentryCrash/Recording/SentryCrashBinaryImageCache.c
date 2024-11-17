#include "SentryCrashBinaryImageCache.h"
#include "SentryCrashDynamicLinker.h"
#include <mach-o/dyld.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#if defined(TEST) || defined(TESTCI) || defined(DEBUG)

typedef void (*SentryRegisterImageCallback)(const struct mach_header *mh, intptr_t vmaddr_slide);
typedef void (*SentryRegisterFunction)(SentryRegisterImageCallback function);

static SentryRegisterFunction _sentry_register_func_for_add_image
    = &_dyld_register_func_for_add_image;
static SentryRegisterFunction _sentry_register_func_for_remove_image
    = &_dyld_register_func_for_remove_image;

static void (*SentryWillAddImageCallback)(void) = NULL;

void
sentry_setRegisterFuncForAddImage(SentryRegisterFunction addFunction)
{
    _sentry_register_func_for_add_image = addFunction;
}

void
sentry_setRegisterFuncForRemoveImage(SentryRegisterFunction removeFunction)
{
    _sentry_register_func_for_remove_image = removeFunction;
}

void
sentry_setFuncForBeforeAdd(void (*callback)(void))
{
    SentryWillAddImageCallback = callback;
}

void
sentry_resetFuncForAddRemoveImage(void)
{
    _sentry_register_func_for_add_image = &_dyld_register_func_for_add_image;
    _sentry_register_func_for_remove_image = &_dyld_register_func_for_remove_image;
}

#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _sentry_register_func_for_add_image(CALLBACK);
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _sentry_register_func_for_remove_image(CALLBACK);
#    define _will_add_image()                                                                      \
        if (SentryWillAddImageCallback)                                                            \
            SentryWillAddImageCallback();
#else
#    define sentry_dyld_register_func_for_add_image(CALLBACK)                                      \
        _dyld_register_func_for_add_image(CALLBACK)
#    define sentry_dyld_register_func_for_remove_image(CALLBACK)                                   \
        _dyld_register_func_for_remove_image(CALLBACK)
#    define _will_add_image()
#endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

typedef struct SentryCrashBinaryImageNode {
    SentryCrashBinaryImage image;
    bool available;
    struct SentryCrashBinaryImageNode *next;
} SentryCrashBinaryImageNode;

static SentryCrashBinaryImageNode rootNode = { 0 };
static SentryCrashBinaryImageNode *tailNode = NULL;
static pthread_mutex_t binaryImagesMutex = PTHREAD_MUTEX_INITIALIZER;

static sentrycrashbic_cacheChangeCallback imageAddedCallback = NULL;
static sentrycrashbic_cacheChangeCallback imageRemovedCallback = NULL;

static void
binaryImageAdded(const struct mach_header *header, intptr_t slide)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    pthread_mutex_unlock(&binaryImagesMutex);
    Dl_info info;
    if (!dladdr(header, &info) || info.dli_fname == NULL) {
        return;
    }

    SentryCrashBinaryImage binaryImage = { 0 };
    if (!sentrycrashdl_getBinaryImageForHeader(
            (const void *)header, info.dli_fname, &binaryImage, false)) {
        return;
    }

    SentryCrashBinaryImageNode *newNode = malloc(sizeof(SentryCrashBinaryImageNode));
    newNode->available = true;
    newNode->image = binaryImage;
    newNode->next = NULL;
    _will_add_image();
    pthread_mutex_lock(&binaryImagesMutex);
    // Recheck tailNode as it could be null when
    // stopped from another thread.
    if (tailNode != NULL) {
        tailNode->next = newNode;
        tailNode = tailNode->next;
    } else {
        free(newNode);
        newNode = NULL;
    }
    pthread_mutex_unlock(&binaryImagesMutex);
    if (newNode && imageAddedCallback) {
        imageAddedCallback(&newNode->image);
    }
}

static void
binaryImageRemoved(const struct mach_header *header, intptr_t slide)
{
    SentryCrashBinaryImageNode *nextNode = &rootNode;

    while (nextNode != NULL) {
        if (nextNode->image.address == (uint64_t)header) {
            nextNode->available = false;
            if (imageRemovedCallback) {
                imageRemovedCallback(&nextNode->image);
            }
            break;
        }
        nextNode = nextNode->next;
    }
}

void
sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback callback, void *context)
{
    /**
     We can't use locks here because this is meant to be used during crashes,
     where we can't use async unsafe functions. In order to avoid potential problems,
     we choose an approach that doesn't remove nodes from the list.
    */
    SentryCrashBinaryImageNode *nextNode = &rootNode;

    // If tailNode is null it means the cache was stopped, therefore we end the iteration.
    // This will minimize any race condition effect without the need for locks.
    while (nextNode != NULL && tailNode != NULL) {
        if (nextNode->available) {
            callback(&nextNode->image, context);
        }
        nextNode = nextNode->next;
    }
}

void
sentrycrashbic_startCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode != NULL) {
        // Already initialized
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }
    tailNode = &rootNode;
    rootNode.next = NULL;
    pthread_mutex_unlock(&binaryImagesMutex);

    // During a call to _dyld_register_func_for_add_image() the callback func is called for every
    // existing image
    sentry_dyld_register_func_for_add_image(&binaryImageAdded);
    sentry_dyld_register_func_for_remove_image(&binaryImageRemoved);
}

void
sentrycrashbic_stopCache(void)
{
    pthread_mutex_lock(&binaryImagesMutex);
    if (tailNode == NULL) {
        pthread_mutex_unlock(&binaryImagesMutex);
        return;
    }

    SentryCrashBinaryImageNode *node = rootNode.next;
    rootNode.next = NULL;
    tailNode = NULL;

    while (node != NULL) {
        SentryCrashBinaryImageNode *nextNode = node->next;
        free(node);
        node = nextNode;
    }

    pthread_mutex_unlock(&binaryImagesMutex);
}

static void
initialReportToCallback(SentryCrashBinaryImage *image, void *context)
{
    sentrycrashbic_cacheChangeCallback callback = (sentrycrashbic_cacheChangeCallback)context;
    callback(image);
}

void
sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    imageAddedCallback = callback;
    if (callback) {
        pthread_mutex_lock(&binaryImagesMutex);
        sentrycrashbic_iterateOverImages(&initialReportToCallback, callback);
        pthread_mutex_unlock(&binaryImagesMutex);
    }
}

void
sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback)
{
    imageRemovedCallback = callback;
}
