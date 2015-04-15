//
//  FABAttributes.h
//  Fabric
//
//  Created by Priyanka Joshi on 3/3/15.
//  Copyright (c) 2015 Twitter. All rights reserved.
//

#pragma once

#define FAB_UNAVAILABLE(x) __attribute__((unavailable(x)))

#if __has_feature(nullability)
#define FAB_NONNULL __nonnull
#define FAB_NULLABLE __nullable
#define FAB_START_NONNULL _Pragma("clang assume_nonnull begin")
#define FAB_END_NONNULL _Pragma("clang assume_nonnull end")
#else
#define FAB_NONNULL
#define FAB_NULLABLE
#define FAB_START_NONNULL
#define FAB_END_NONNULL
#endif
