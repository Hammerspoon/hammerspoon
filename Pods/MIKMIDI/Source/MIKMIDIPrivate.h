//
//  MIKMIDIPrivate.h
//  MIKMIDI
//
//  Created by Andrew Madsen on 10/29/13.
//  Copyright (c) 2013 Mixed In Key. All rights reserved.
//

#if OS_OBJECT_HAVE_OBJC_SUPPORT && __has_feature(objc_arc)
#define MIKMIDI_GCD_RELEASE(x)
#define MIKMIDI_GCD_RETAIN(x)
#else
#define MIKMIDI_GCD_RELEASE(x) dispatch_release(x)
#define MIKMIDI_GCD_RETAIN(x) dispatch_retain(x)
#endif
