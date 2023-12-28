#ifndef SentryCrashBinaryImageCache_h
#define SentryCrashBinaryImageCache_h

#include "SentryCrashDynamicLinker.h"
#include <stdio.h>

typedef void (*sentrycrashbic_imageIteratorCallback)(SentryCrashBinaryImage *, void *context);

typedef void (*sentrycrashbic_cacheChangeCallback)(const SentryCrashBinaryImage *binaryImage);

void sentrycrashbic_iterateOverImages(sentrycrashbic_imageIteratorCallback index, void *context);

/**
 * Starts the cache that will monitor binary image being loaded or removed.
 */
void sentrycrashbic_startCache(void);

/**
 * Stops the cache from monitoring binary image being loaded or removed.
 * This will also clean the cache.
 */
void sentrycrashbic_stopCache(void);

/**
 * Register a callback to be called every time a new binary image is added to the cache.
 * After register, this callback will be called for every image already in the cache,
 * this is a thread safe operation.
 */
void sentrycrashbic_registerAddedCallback(sentrycrashbic_cacheChangeCallback callback);

/**
 * Register a callback to be called every time a binary image is remove from the cache.
 */
void sentrycrashbic_registerRemovedCallback(sentrycrashbic_cacheChangeCallback callback);

#endif /* SentryCrashBinaryImageCache_h */
