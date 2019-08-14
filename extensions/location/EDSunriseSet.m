//
//  EDSunriseSet.m
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

#import "EDSunriseSet.h"

//
// Defines from sunriset.c
//
#define INV360    ( 1.0 / 360.0 )

#define RADEG     ( 180.0 / M_PI )
#define DEGRAD    ( M_PI / 180.0 )

/* The trigonometric functions in degrees */

#define sind(x)  sin((x)*DEGRAD)
#define cosd(x)  cos((x)*DEGRAD)
#define tand(x)  tan((x)*DEGRAD)

#define atand(x)    (RADEG*atan(x))
#define asind(x)    (RADEG*asin(x))
#define acosd(x)    (RADEG*acos(x))
#define atan2d(y,x) (RADEG*atan2(y,x))

/* A macro to compute the number of days elapsed since 2000 Jan 0.0 */
/* (which is equal to 1999 Dec 31, 0h UT)                           */
#define days_since_2000_Jan_0(y,m,d) \
(367L*(y)-((7*((y)+(((m)+9)/12)))/4)+((275*(m))/9)+(d)-730530L)


#if defined(__IPHONE_8_0) || defined (__MAC_10_10)
#define EDGregorianCalendar NSCalendarIdentifierGregorian
#else
#define EDGregorianCalendar NSGregorianCalendar
#endif


#pragma mark - Readwrite accessors only private
@interface EDSunriseSet()

@property (nonatomic) double  latitude;
@property (nonatomic) double  longitude;
@property (nonatomic, strong) NSTimeZone *timezone;
@property (nonatomic, strong) NSCalendar *calendar;
@property (nonatomic, strong) NSTimeZone *utcTimeZone;

@property (readwrite, strong) NSDate *date;
@property (readwrite, strong) NSDate *sunset;
@property (readwrite, strong) NSDate *sunrise;
@property (readwrite, strong) NSDate *civilTwilightStart;
@property (readwrite, strong) NSDate *civilTwilightEnd;
@property (readwrite, strong) NSDate *nauticalTwilightStart;
@property (readwrite, strong) NSDate *nauticalTwilightEnd;
@property (readwrite, strong) NSDate *astronomicalTwilightStart;
@property (readwrite, strong) NSDate *astronomicalTwilightEnd;

@property (readwrite, strong) NSDateComponents* localSunrise;
@property (readwrite, strong) NSDateComponents* localSunset;
@property (readwrite, strong) NSDateComponents* localCivilTwilightStart;
@property (readwrite, strong) NSDateComponents* localCivilTwilightEnd;
@property (readwrite, strong) NSDateComponents* localNauticalTwilightStart;
@property (readwrite, strong) NSDateComponents* localNauticalTwilightEnd;
@property (readwrite, strong) NSDateComponents* localAstronomicalTwilightStart;
@property (readwrite, strong) NSDateComponents* localAstronomicalTwilightEnd;

@end

#pragma mark - Calculations from sunriset.c
@implementation EDSunriseSet(Calculations)

/*****************************************/
/* Reduce angle to within 0..360 degrees */
/*****************************************/
-(double) revolution:(double) x
{
    return( x - 360.0 * floor( x * INV360 ) );
}

/*********************************************/
/* Reduce angle to within -180..+180 degrees */
/*********************************************/
-(double)  rev180:(double) x
{
    return( x - 360.0 * floor( x * INV360 + 0.5 ) );
}

-(double) GMST0:(double) d
{
    double sidtim0;
    /* Sidtime at 0h UT = L (Sun's mean longitude) + 180.0 degr  */
    /* L = M + w, as defined in sunpos().  Since I'm too lazy to */
    /* add these numbers, I'll let the C compiler do it for me.  */
    /* Any decent C compiler will add the constants at compile   */
    /* time, imposing no runtime or code overhead.               */
    sidtim0 = [self revolution: ( 180.0 + 356.0470 + 282.9404 ) +
               ( 0.9856002585 + 4.70935E-5 ) * d];
    return sidtim0;
}

/******************************************************/
/* Computes the Sun's ecliptic longitude and distance */
/* at an instant given in d, number of days since     */
/* 2000 Jan 0.0.  The Sun's ecliptic latitude is not  */
/* computed, since it's always very near 0.           */
/******************************************************/
-(void) sunposAtDay:(double)d longitude:(double*)lon r:(double *)r
{
    double M,         /* Mean anomaly of the Sun */
    w,         /* Mean longitude of perihelion */
    /* Note: Sun's mean longitude = M + w */
    e,         /* Eccentricity of Earth's orbit */
    E,         /* Eccentric anomaly */
    x, y,      /* x, y coordinates in orbit */
    v;         /* True anomaly */
    
    /* Compute mean elements */
    M = [self revolution:( 356.0470 + 0.9856002585 * d )];
    w = 282.9404 + 4.70935E-5 * d;
    e = 0.016709 - 1.151E-9 * d;
    
    /* Compute true longitude and radius vector */
    E = M + e * RADEG * sind(M) * ( 1.0 + e * cosd(M) );
    x = cosd(E) - e;
    y = sqrt( 1.0 - e*e ) * sind(E);
    *r = sqrt( x*x + y*y );              /* Solar distance */
    v = atan2d( y, x );                  /* True anomaly */
    *lon = v + w;                        /* True solar longitude */
    if ( *lon >= 360.0 )
        *lon -= 360.0;                   /* Make it 0..360 degrees */
}

-(void) sun_RA_decAtDay:(double)d RA:(double*)RA decl:(double *)dec  r:(double *)r
{
    double lon, obl_ecl;
    double xs, ys, zs;
    double xe, ye, ze;
    
    /* Compute Sun's ecliptical coordinates */
    //sunpos( d, &lon, r );
    [self sunposAtDay:d longitude:&lon r:r];
    
    /* Compute ecliptic rectangular coordinates */
    xs = *r * cosd(lon);
    ys = *r * sind(lon);
    zs = 0; /* because the Sun is always in the ecliptic plane! */
    
    /* Compute obliquity of ecliptic (inclination of Earth's axis) */
    obl_ecl = 23.4393 - 3.563E-7 * d;
    
    /* Convert to equatorial rectangular coordinates - x is unchanged */
    xe = xs;
    ye = ys * cosd(obl_ecl);
    ze = ys * sind(obl_ecl);
    
    /* Convert to spherical coordinates */
    *RA = atan2d( ye, xe );
    *dec = atan2d( ze, sqrt(xe*xe + ye*ye) );
    
}  /* sun_RA_dec */

#define sun_rise_set(year,month,day,lon,lat,rise,set)  \
__sunriset__( year, month, day, lon, lat, -35.0/60.0, 1, rise, set )

-(int)sunRiseSetForYear:(int)year month:(int)month day:(int)day longitude:(double)lon latitude:(double)lat
                  trise:(double *)trise tset:(double *)tset
{
    
    return [self sunRiseSetHelperForYear:year month:month day:day longitude:lon latitude:lat altitude:(-35.0/60.0)
                              upper_limb:1 trise:trise tset:tset];
    
}
/*
 #define civil_twilight(year,month,day,lon,lat,start,end)  \
 __sunriset__( year, month, day, lon, lat, -6.0, 0, start, end )
 */
-(int) civilTwilightForYear:(int)year  month:(int)month day:(int)day longitude:(double)lon latitude:(double)lat
                      trise:(double *)trise tset:(double *)tset
{
    return [self sunRiseSetHelperForYear:year month:month day:day longitude:lon latitude:lat altitude:-6.0
                              upper_limb:0 trise:trise tset:tset];
}
/*
 #define nautical_twilight(year,month,day,lon,lat,start,end)  \
 __sunriset__( year, month, day, lon, lat, -12.0, 0, start, end )
 */
-(int) nauticalTwilightForYear:(int)year  month:(int)month day:(int)day longitude:(double)lon latitude:(double)lat
                         trise:(double *)trise tset:(double *)tset
{
    return [self sunRiseSetHelperForYear:year month:month day:day longitude:lon latitude:lat altitude:-12.0
                              upper_limb:0 trise:trise tset:tset];
}
/*
 #define astronomical_twilight(year,month,day,lon,lat,start,end)  \
 __sunriset__( year, month, day, lon, lat, -18.0, 0, start, end )
 */
-(int) astronomicalTwilightForYear:(int)year  month:(int)month day:(int)day longitude:(double)lon latitude:(double)lat
                             trise:(double *)trise tset:(double *)tset
{
    return [self sunRiseSetHelperForYear:year month:month day:day longitude:lon latitude:lat altitude:-18.0
                              upper_limb:0 trise:trise tset:tset];
}

/***************************************************************************/
/* Note: year,month,date = calendar date, 1801-2099 only.             */
/*       Eastern longitude positive, Western longitude negative       */
/*       Northern latitude positive, Southern latitude negative       */
/*       The longitude value IS critical in this function!            */
/*       altit = the altitude which the Sun should cross              */
/*               Set to -35/60 degrees for rise/set, -6 degrees       */
/*               for civil, -12 degrees for nautical and -18          */
/*               degrees for astronomical twilight.                   */
/*         upper_limb: non-zero -> upper limb, zero -> center         */
/*               Set to non-zero (e.g. 1) when computing rise/set     */
/*               times, and to zero when computing start/end of       */
/*               twilight.                                            */
/*        *rise = where to store the rise time                        */
/*        *set  = where to store the set  time                        */
/*                Both times are relative to the specified altitude,  */
/*                and thus this function can be used to comupte       */
/*                various twilight times, as well as rise/set times   */
/* Return value:  0 = sun rises/sets this day, times stored at        */
/*                    *trise and *tset.                               */
/*               +1 = sun above the specified "horizon" 24 hours.     */
/*                    *trise set to time when the sun is at south,    */
/*                    minus 12 hours while *tset is set to the south  */
/*                    time plus 12 hours. "Day" length = 24 hours     */
/*               -1 = sun is below the specified "horizon" 24 hours   */
/*                    "Day" length = 0 hours, *trise and *tset are    */
/*                    both set to the time when the sun is at south.  */
/*                                                                    */
/**********************************************************************/
-(int)sunRiseSetHelperForYear:(int)year month:(int)month day:(int)day longitude:(double)lon latitude:(double)lat
                     altitude:(double)altit upper_limb:(int)upper_limb trise:(double *)trise tset:(double *)tset
{
    double  d,  /* Days since 2000 Jan 0.0 (negative before) */
    sr,         /* Solar distance, astronomical units */
    sRA,        /* Sun's Right Ascension */
    sdec,       /* Sun's declination */
    sradius,    /* Sun's apparent radius */
    t,          /* Diurnal arc */
    tsouth,     /* Time when Sun is at south */
    sidtime;    /* Local sidereal time */
    
    int rc = 0; /* Return cde from function - usually 0 */
    
    /* Compute d of 12h local mean solar time */
    d = days_since_2000_Jan_0(year,month,day) + 0.5 - lon/360.0;
    
    
    /* Compute local sideral time of this moment */
    //sidtime = revolution( GMST0(d) + 180.0 + lon );
    sidtime  = [self revolution:[self GMST0:d] + 180.0 + lon];
    /* Compute Sun's RA + Decl at this moment */
    //sun_RA_dec( d, &sRA, &sdec, &sr );
    [self sun_RA_decAtDay:d RA: &sRA decl:&sdec r:&sr];
    
    /* Compute time when Sun is at south - in hours UT */
    //tsouth = 12.0 - rev180(sidtime - sRA)/15.0;
    tsouth = 12.0 - [self rev180:sidtime - sRA] / 15.0;
    
    /* Compute the Sun's apparent radius, degrees */
    sradius = 0.2666 / sr;
    
    /* Do correction to upper limb, if necessary */
    if ( upper_limb )
        altit -= sradius;
    
    /* Compute the diurnal arc that the Sun traverses to reach */
    /* the specified altitide altit: */
    {
        double cost;
        cost = ( sind(altit) - sind(lat) * sind(sdec) ) /
        ( cosd(lat) * cosd(sdec) );
        if ( cost >= 1.0 ) {
            rc = -1;
            t = 0.0;       /* Sun always below altit */
        } else if ( cost <= -1.0 ) {
            rc = +1;
            t = 12.0;      /* Sun always above altit */
        } else {
            t = acosd(cost)/15.0;   /* The diurnal arc, hours */
        }
    }
    
    /* Store rise and set times - in hours UT */
    *trise = tsouth - t;
    *tset  = tsouth + t;
    
    return rc;
}  /* __sunriset__ */


@end


#pragma mark - Private Implementation

@implementation EDSunriseSet(Private)

static const int kSecondsInHour= 60.0*60.0;


-(NSDate*)utcTime:(NSDateComponents*)dateComponents withOffset:(NSTimeInterval)interval
{
    [self.calendar setTimeZone:self.utcTimeZone];
    return [[self.calendar dateFromComponents:dateComponents] dateByAddingTimeInterval:(NSTimeInterval)(interval)];
}

-(NSDateComponents*)localTime:(NSDate*)refDate
{
    [self.calendar setTimeZone:self.timezone];
    // Return only hour, minute, seconds
    NSDateComponents *dc = [self.calendar components:( NSCalendarUnitHour  | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:refDate] ;
    
    return dc;
}

-(NSString *)description
{
    return [NSString stringWithFormat:
                @"Date: %@\nTimeZone: %@\n"
                @"Local Sunrise: %@\n"
                @"Local Sunset: %@\n"
                @"Local Civil Twilight Start: %@\n"
                @"Local Civil Twilight End: %@\n"
                @"Local Nautical Twilight Start: %@\n"
                @"Local Nautical Twilight End: %@\n"
                @"Local Astronomical Twilight Start: %@\n"
                @"Local Astronomical Twilight End: %@\n",
                self.date.description, self.timezone.name,
                self.localSunrise.description, self.localSunset.description,
                self.localCivilTwilightStart, self.localCivilTwilightEnd,
                self.localNauticalTwilightStart, self.localNauticalTwilightEnd,
                self.localAstronomicalTwilightStart, self.localAstronomicalTwilightEnd
            ];
}

#pragma mark - Calculation methods

-(void)calculateSunriseSunset
{
    // Get date components
    [self.calendar setTimeZone:self.timezone];
    NSDateComponents *dateComponents = [self.calendar components:( NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay ) fromDate:self.date];
    
    // Calculate sunrise and sunset
    double rise=0.0, set=0.0;
    [self sunRiseSetForYear:(int)[dateComponents year] month:(int)[dateComponents month] day:(int)[dateComponents day] longitude:self.longitude latitude:self.latitude
                      trise:&rise tset:&set ];
    NSTimeInterval secondsRise  = rise*kSecondsInHour;
    NSTimeInterval secondsSet   = set*kSecondsInHour;
    
    self.sunrise = [self utcTime:dateComponents withOffset:(NSTimeInterval)secondsRise];
    self.sunset  = [self utcTime:dateComponents withOffset:(NSTimeInterval)secondsSet];
    self.localSunrise = [self localTime:self.sunrise];
    self.localSunset = [self localTime:self.sunset];
}

-(void)calculateTwilight
{
    // Get date components
    [self.calendar setTimeZone:self.timezone];
    NSDateComponents *dateComponents = [self.calendar components:( NSCalendarUnitYear | NSCalendarUnitMonth |  NSCalendarUnitDay ) fromDate:self.date];
    double start=0.0, end=0.0;
    
    // Civil twilight
    [self civilTwilightForYear:(int)[dateComponents year] month:(int)[dateComponents month] day:(int)[dateComponents day] longitude:self.longitude latitude:self.latitude
                         trise:&start tset:&end ];
    self.civilTwilightStart = [self utcTime:dateComponents withOffset:(NSTimeInterval)(start*kSecondsInHour)];
    self.civilTwilightEnd  = [self utcTime:dateComponents withOffset:(NSTimeInterval)(end*kSecondsInHour)];
    self.localCivilTwilightStart = [self localTime:self.civilTwilightStart];
    self.localCivilTwilightEnd = [self localTime:self.civilTwilightEnd];
    
    // Nautical twilight
    [self nauticalTwilightForYear:(int)[dateComponents year] month:(int)[dateComponents month] day:(int)[dateComponents day] longitude:self.longitude latitude:self.latitude
                            trise:&start tset:&end ];
    self.nauticalTwilightStart = [self utcTime:dateComponents withOffset:(NSTimeInterval)(start*kSecondsInHour)];
    self.nauticalTwilightEnd  = [self utcTime:dateComponents withOffset:(NSTimeInterval)(end*kSecondsInHour)];
    self.localNauticalTwilightStart = [self localTime:self.nauticalTwilightStart];
    self.localNauticalTwilightEnd = [self localTime:self.nauticalTwilightEnd];
    // Astronomical twilight
    [self astronomicalTwilightForYear:(int)[dateComponents year] month:(int)[dateComponents month] day:(int)[dateComponents day] longitude:self.longitude latitude:self.latitude
                                trise:&start tset:&end ];
    self.astronomicalTwilightStart = [self utcTime:dateComponents withOffset:(NSTimeInterval)(start*kSecondsInHour)];
    self.astronomicalTwilightEnd  = [self utcTime:dateComponents withOffset:(NSTimeInterval)(end*kSecondsInHour)];
    self.localAstronomicalTwilightStart = [self localTime:self.astronomicalTwilightStart];
    self.localAstronomicalTwilightEnd = [self localTime:self.astronomicalTwilightEnd];
}

-(void)calculate
{
    [self calculateSunriseSunset];
    [self calculateTwilight];
}

@end


#pragma mark - Public Implementation

@implementation EDSunriseSet

#pragma mark - Initialization

-(EDSunriseSet*)initWithDate:(NSDate*)date timezone:(NSTimeZone*)tz latitude:(double)latitude longitude:(double)longitude {
    self = [super init];
    if( self )
    {
        self.latitude = latitude;
        self.longitude = longitude;
        self.timezone = tz;
        self.date = date;
        
        self.calendar = [[NSCalendar alloc] initWithCalendarIdentifier:EDGregorianCalendar];
        self.utcTimeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
        
        [self calculate];

    }
    return self;
}

+(EDSunriseSet*)sunrisesetWithDate:(NSDate*)date timezone:(NSTimeZone*)tz latitude:(double)latitude longitude:(double)longitude {
    return [[EDSunriseSet alloc] initWithDate:date timezone:tz latitude:latitude longitude:longitude];
}

@end
