//
//  EDSunriseSet.h
//
//  Created by Ernesto García  on 20/08/11.
//  Copyright 2011 Ernesto García. All rights reserved.
//

//  C/C++ sun calculations created by Paul Schlyter
//  sunriset.c 
//  http://stjarnhimlen.se/english.html
//  SUNRISET.C - computes Sun rise/set times, start/end of twilight, and
//  the length of the day at any date and latitude
//  Written as DAYLEN.C, 1989-08-16
//  Modified to SUNRISET.C, 1992-12-01
//  (c) Paul Schlyter, 1989, 1992
//  Released to the public domain by Paul Schlyter, December 1992
//

#import <Foundation/Foundation.h>

#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Either turn on ARC for the project or use -fobjc-arc flag in this file.
#endif

@interface EDSunriseSet : NSObject

@property (readonly, strong) NSDate *date;
@property (readonly, strong) NSDate *sunset;
@property (readonly, strong) NSDate *sunrise;
@property (readonly, strong) NSDate *civilTwilightStart;
@property (readonly, strong) NSDate *civilTwilightEnd;
@property (readonly, strong) NSDate *nauticalTwilightStart;
@property (readonly, strong) NSDate *nauticalTwilightEnd;
@property (readonly, strong) NSDate *astronomicalTwilightStart;
@property (readonly, strong) NSDate *astronomicalTwilightEnd;

@property (readonly, strong) NSDateComponents* localSunrise;
@property (readonly, strong) NSDateComponents* localSunset;
@property (readonly, strong) NSDateComponents* localCivilTwilightStart;
@property (readonly, strong) NSDateComponents* localCivilTwilightEnd;
@property (readonly, strong) NSDateComponents* localNauticalTwilightStart;
@property (readonly, strong) NSDateComponents* localNauticalTwilightEnd;
@property (readonly, strong) NSDateComponents* localAstronomicalTwilightStart;
@property (readonly, strong) NSDateComponents* localAstronomicalTwilightEnd;


-(instancetype)initWithDate:(NSDate*)date timezone:(NSTimeZone*)timezone latitude:(double)latitude longitude:(double)longitude NS_DESIGNATED_INITIALIZER;
+(instancetype)sunrisesetWithDate:(NSDate*)date timezone:(NSTimeZone*)timezone latitude:(double)latitude longitude:(double)longitude;
-(instancetype) init __attribute__((unavailable("init not available. Use initWithDate:timeZone:latitude:longitude: instead")));

@end
