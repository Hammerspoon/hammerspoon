#import "Canvas.h"

#define VIEW_DEBUG

static const char *USERDATA_TAG = "hs.canvas" ;
static LSRefTable refTable = LUA_NOREF;
static BOOL defaultCustomSubRole = YES ;

// Can't have "static" or "constant" dynamic NSObjects like NSArray, so define in lua_open
static NSDictionary *languageDictionary ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

typedef NS_ENUM(NSInteger, attributeValidity) {
    attributeValid,
    attributeNulling,
    attributeInvalid,
};

#pragma mark - Support Functions and Classes

static int cg_windowLevels(lua_State *L) ;

static BOOL parentIsWindow(NSView *theView) {
    BOOL isWindow = NO ;
    NSWindow *owningWindow = theView.window ;
    if (owningWindow && [owningWindow.contentView isEqualTo:theView]) isWindow = YES ;
//     [LuaSkin logWarn:(isWindow ? @"parent is a window" : @"parent is a view")] ;
    return isWindow ;
}

static NSDictionary *defineLanguageDictionary() {
    // the default shadow has no offset or blur radius, so lets setup one that is at least visible
    NSShadow *defaultShadow = [[NSShadow alloc] init] ;
    [defaultShadow setShadowOffset:NSMakeSize(5.0, -5.0)];
    [defaultShadow setShadowBlurRadius:5.0];
//     [defaultShadow setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.3]];

    return @{
        @"action" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"default"     : @"strokeAndFill",
            @"values"      : @[ @"stroke", @"fill", @"strokeAndFill", @"clip", @"build", @"skip" ],
            @"nullable" : @(YES),
            @"optionalFor" : ALL_TYPES,
        },
        @"absolutePosition" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),  // @encode may change depending upon architecture, so use the
                                                    // same value we check against in isValueValidForDictionary
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"absoluteSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"antialias" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"arcRadii" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"arcClockwise" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(YES),
            @"optionalFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"clipToPath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : CLOSED,
        },
        @"compositeRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [COMPOSITING_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"sourceOver",
            @"optionalFor" : VISIBLE,
        },
        @"center" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"50%",
                                   @"y" : @"50%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"circle", @"arc" ],
        },
        @"closed" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(NO),
            @"default"     : @(NO),
            @"requiredFor" : @[ @"segments" ],
        },
        @"coordinates" : @{
            @"class"           : @[ [NSArray class] ],
            @"luaClass"        : @"table",
            @"default"         : @[ ],
            @"nullable"        : @(NO),
            @"requiredFor"     : @[ @"segments", @"points" ],
            @"memberClass"     : [NSDictionary class],
            @"memberLuaClass"  : @"point table",
            @"memberClassKeys" : @{
                @"x"   : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"requiredFor" : @[ @"segments", @"points" ],
                    @"nullable"    : @(NO),
                },
                @"y"   : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"requiredFor" : @[ @"segments", @"points" ],
                    @"nullable"    : @(NO),
                },
                @"c1x" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c1y" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c2x" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
                @"c2y" : @{
                    @"class"       : @[ [NSNumber class], [NSString class] ],
                    @"luaClass"    : @"number or string",
                    @"default"     : @"0.0",
                    @"optionalFor" : @[ @"segments" ],
                    @"nullable"    : @(YES),
                },
            },
        },
        @"endAngle" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(360.0),
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"fillColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor redColor],
            @"optionalFor" : CLOSED,
        },
        @"fillGradient" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : @[
                                   @"none",
                                   @"linear",
                                   @"radial",
                             ],
            @"nullable"    : @(YES),
            @"default"     : @"none",
            @"optionalFor" : CLOSED,
        },
        @"fillGradientAngle"  : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(0.0),
            @"optionalFor" : CLOSED,
        },
        @"fillGradientCenter" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"     : @[ [NSNumber class] ],
                    @"luaClass"  : @"number",
                    @"maxNumber" : @(1.0),
                    @"minNumber" : @(-1.0),
                },
                @"y" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                    @"maxNumber" : @(1.0),
                    @"minNumber" : @(-1.0),
                },
            },
            @"default"       : @{
                                   @"x" : @(0.0),
                                   @"y" : @(0.0),
                               },
            @"nullable"      : @(YES),
            @"optionalFor"   : CLOSED,
        },
        @"fillGradientColors" : @{
            @"class"          : @[ [NSArray class] ],
            @"luaClass"       : @"table",
            @"default"        : @[ [NSColor blackColor], [NSColor whiteColor] ],
            @"memberClass"    : [NSColor class],
            @"memberLuaClass" : @"hs.drawing.color table",
            @"nullable"       : @(YES),
            @"optionalFor"    : CLOSED,
        },
        @"flatness" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @([NSBezierPath defaultFlatness]),
            @"optionalFor" : PRIMITIVES,
        },
        @"flattenPath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
        @"frame" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"x" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"y" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"h" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
                @"w" : @{
                    @"class"    : @[ [NSString class], [NSNumber class] ],
                    @"luaClass" : @"number or string",
                },
            },
            @"default"       : @{
                                   @"x" : @"0%",
                                   @"y" : @"0%",
                                   @"h" : @"100%",
                                   @"w" : @"100%",
                               },
            @"nullable"      : @(NO),
            @"requiredFor"   : @[ @"rectangle", @"oval", @"ellipticalArc", @"text", @"image", @"canvas" ],
        },
        @"id" : @{
            @"class"       : @[ [NSString class], [NSNumber class] ],
            @"luaClass"    : @"string or number",
            @"nullable"    : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"image" : @{
            @"class"       : @[ [NSImage class] ],
            @"luaClass"    : @"hs.image object",
            @"nullable"    : @(YES),
            @"default"     : [NSNull null],
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAlpha" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(1.0),
            @"minNumber"   : @(0.0),
            @"maxNumber"   : @(1.0),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAlignment" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [IMAGEALIGNMENT_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"center",
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAnimationFrame" : @ {
            @"class"       : @[ [NSNumber class] ],
            @"objCType"    : @([@((lua_Integer)1) objCType]), // @encode may change depending upon architecture, so use the
                                                              // same value we check against in isValueValidForDictionary
            @"luaClass"    : @"integer",
            @"nullable"    : @(YES),
            @"default"     : @(0),
            @"optionalFor" : @[ @"image" ],
        },
        @"imageAnimates" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(NO),
            @"default"     : @(NO),
            @"requiredFor" : @[ @"image" ],
        },
        @"imageScaling" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [IMAGESCALING_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"scaleProportionally",
            @"optionalFor" : @[ @"image" ],
        },
        @"miterLimit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultMiterLimit]),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"padding" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(YES),
            @"optionalFor" : VISIBLE,
        },
        @"radius" : @{
            @"class"       : @[ [NSNumber class], [NSString class] ],
            @"luaClass"    : @"number or string",
            @"nullable"    : @(NO),
            @"default"     : @"50%",
            @"requiredFor" : @[ @"arc", @"circle" ],
        },
        @"reversePath" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
        @"roundedRectRadii" : @{
            @"class"         : @[ [NSDictionary class] ],
            @"luaClass"      : @"table",
            @"keys"          : @{
                @"xRadius" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                },
                @"yRadius" : @{
                    @"class"    : @[ [NSNumber class] ],
                    @"luaClass" : @"number",
                },
            },
            @"default"       : @{
                                   @"xRadius" : @(0.0),
                                   @"yRadius" : @(0.0),
                               },
            @"nullable"      : @(YES),
            @"optionalFor"   : @[ @"rectangle" ],
        },
        @"shadow" : @{
            @"class"       : @[ [NSShadow class] ],
            @"luaClass"    : @"shadow table",
            @"nullable"    : @(YES),
            @"default"     : defaultShadow,
            @"optionalFor" : PRIMITIVES,
        },
        @"startAngle" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(NO),
            @"requiredFor" : @[ @"arc", @"ellipticalArc" ],
        },
        @"strokeCapStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [STROKE_CAP_STYLES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"butt",
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor blackColor],
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeDashPattern" : @{
            @"class"          : @[ [NSArray class] ],
            @"luaClass"       : @"table",
            @"nullable"       : @(YES),
            @"default"        : @[ ],
            @"memberClass"    : [NSNumber class],
            @"memberLuaClass" : @"number",
            @"optionalFor"    : PRIMITIVES,
        },
        @"strokeDashPhase" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @(0.0),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeJoinStyle" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [STROKE_JOIN_STYLES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"miter",
            @"optionalFor" : PRIMITIVES,
        },
        @"strokeWidth" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"default"     : @([NSBezierPath defaultLineWidth]),
            @"nullable"    : @(YES),
            @"optionalFor" : PRIMITIVES,
        },
        @"text" : @{
            @"class"       : @[ [NSString class], [NSNumber class], [NSAttributedString class] ],
            @"luaClass"    : @"string or hs.styledText object",
            @"default"     : @"",
            @"nullable"    : @(YES),
            @"requiredFor" : @[ @"text" ],
        },
        @"textAlignment" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [TEXTALIGNMENT_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"natural",
            @"optionalFor" : @[ @"text" ],
        },
        @"textColor" : @{
            @"class"       : @[ [NSColor class] ],
            @"luaClass"    : @"hs.drawing.color table",
            @"nullable"    : @(YES),
            @"default"     : [NSColor colorWithCalibratedWhite:1.0 alpha:1.0],
            @"optionalFor" : @[ @"text" ],
        },
        @"textFont" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"nullable"    : @(YES),
            @"default"     : [[NSFont systemFontOfSize:0] fontName],
            @"optionalFor" : @[ @"text" ],
        },
        @"textLineBreak" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [TEXTWRAP_TYPES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"wordWrap",
            @"optionalFor" : @[ @"text" ],
        },
        @"textSize" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(27.0),
            @"optionalFor" : @[ @"text" ],
        },
        @"trackMouseByBounds" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseEnterExit" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseDown" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseUp" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"trackMouseMove" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : VISIBLE,
        },
        @"transformation" : @{
            @"class"       : @[ [NSAffineTransform class] ],
            @"luaClass"    : @"transform table",
            @"nullable"    : @(YES),
            @"default"     : [NSAffineTransform transform],
            @"optionalFor" : VISIBLE,
        },
        @"type" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : ALL_TYPES,
            @"nullable"    : @(NO),
            @"requiredFor" : ALL_TYPES,
        },
        @"canvas" : @{
            @"class"       : @[ [NSView class] ],
            @"luaClass"    : @"userdata object subclassing NSView",
            @"nullable"    : @(YES),
            @"default"     : [NSNull null],
            @"requiredFor" : @[ @"canvas" ],
        },
        @"canvasAlpha" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"number",
            @"nullable"    : @(YES),
            @"default"     : @(1.0),
            @"minNumber"   : @(0.0),
            @"maxNumber"   : @(1.0),
            @"optionalFor" : @[ @"canvas" ],
        },
        @"windingRule" : @{
            @"class"       : @[ [NSString class] ],
            @"luaClass"    : @"string",
            @"values"      : [WINDING_RULES allKeys],
            @"nullable"    : @(YES),
            @"default"     : @"nonZero",
            @"optionalFor" : PRIMITIVES,
        },
        @"withShadow" : @{
            @"class"       : @[ [NSNumber class] ],
            @"luaClass"    : @"boolean",
            @"objCType"    : @([@(YES) objCType]),
            @"nullable"    : @(YES),
            @"default"     : @(NO),
            @"optionalFor" : PRIMITIVES,
        },
    } ;
}


static attributeValidity isValueValidForDictionary(NSString *keyName, id keyValue, NSDictionary *attributeDefinition) {
    __block attributeValidity validity = attributeValid ;
    __block NSString          *errorMessage ;

    BOOL checked = NO ;
    while (!checked) {  // doing this as a loop so we can break out as soon as we know enough
        checked = YES ; // but we really don't want to loop

        if (!keyValue || [keyValue isKindOfClass:[NSNull class]]) {
            if (attributeDefinition[@"nullable"] && [attributeDefinition[@"nullable"] boolValue]) {
                validity = attributeNulling ;
            } else {
                errorMessage = [NSString stringWithFormat:@"%@ is not nullable", keyName] ;
            }
            break ;
        }

        if ([attributeDefinition[@"class"] isKindOfClass:[NSArray class]]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [attributeDefinition[@"class"] count] ; i++) {
                found = [keyValue isKindOfClass:attributeDefinition[@"class"][i]] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        } else {
            if (![keyValue isKindOfClass:attributeDefinition[@"class"]]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if (attributeDefinition[@"objCType"]) {
            if (strcmp([attributeDefinition[@"objCType"] UTF8String], [keyValue objCType])) {
                errorMessage = [NSString stringWithFormat:@"%@ must be a %@", keyName, attributeDefinition[@"luaClass"]] ;
                break ;
            }
        }

        if ([keyValue isKindOfClass:[NSNumber class]] && !attributeDefinition[@"objCType"]) {
          if (!isfinite([keyValue doubleValue])) {
              errorMessage = [NSString stringWithFormat:@"%@ must be a finite number", keyName] ;
              break ;
          }
        }


        if (attributeDefinition[@"values"]) {
            BOOL found = NO ;
            for (NSUInteger i = 0 ; i < [attributeDefinition[@"values"] count] ; i++) {
                found = [attributeDefinition[@"values"][i] isEqualToString:keyValue] ;
                if (found) break ;
            }
            if (!found) {
                errorMessage = [NSString stringWithFormat:@"%@ must be one of %@", keyName, [attributeDefinition[@"values"] componentsJoinedByString:@", "]] ;
                break ;
            }
        }

        if (attributeDefinition[@"maxNumber"]) {
            if ([keyValue doubleValue] > [attributeDefinition[@"maxNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be <= %f", keyName, [attributeDefinition[@"maxNumber"] doubleValue]] ;
                break ;
            }
        }

        if (attributeDefinition[@"minNumber"]) {
            if ([keyValue doubleValue] < [attributeDefinition[@"minNumber"] doubleValue]) {
                errorMessage = [NSString stringWithFormat:@"%@ must be >= %f", keyName, [attributeDefinition[@"minNumber"] doubleValue]] ;
                break ;
            }
        }

        if ([keyValue isKindOfClass:[NSDictionary class]]) {
            NSDictionary *subKeys = attributeDefinition[@"keys"] ;
            for (NSString *subKeyName in subKeys) {
                NSDictionary *subKeyMiniDefinition = subKeys[subKeyName] ;
                if ([subKeyMiniDefinition[@"class"] isKindOfClass:[NSArray class]]) {
                    BOOL found = NO ;
                    for (NSUInteger i = 0 ; i < [subKeyMiniDefinition[@"class"] count] ; i++) {
                        found = [keyValue[subKeyName] isKindOfClass:subKeyMiniDefinition[@"class"][i]] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                } else {
                    if (![keyValue[subKeyName] isKindOfClass:subKeyMiniDefinition[@"class"]]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"objCType"]) {
                    if (strcmp([subKeyMiniDefinition[@"objCType"] UTF8String], [keyValue[subKeyName] objCType])) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a %@", subKeyName, keyName, subKeyMiniDefinition[@"luaClass"]] ;
                        break ;
                    }
                }

                if ([keyValue[subKeyName] isKindOfClass:[NSNumber class]] && !subKeyMiniDefinition[@"objCType"]) {
                  if (!isfinite([keyValue[subKeyName] doubleValue])) {
                      errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be a finite number", subKeyName, keyName] ;
                      break ;
                  }
                }

                if (subKeyMiniDefinition[@"values"]) {
                    BOOL found = NO ;
                    NSString *subKeyValue = keyValue[subKeyName] ;
                    for (NSUInteger i = 0 ; i < [subKeyMiniDefinition[@"values"] count] ; i++) {
                        found = [subKeyMiniDefinition[@"values"][i] isEqualToString:subKeyValue] ;
                        if (found) break ;
                    }
                    if (!found) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be one of %@", subKeyName, keyName, [subKeyMiniDefinition[@"values"] componentsJoinedByString:@", "]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"maxNumber"]) {
                    if ([keyValue[subKeyName] doubleValue] > [subKeyMiniDefinition[@"maxNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be <= %f", subKeyName, keyName, [subKeyMiniDefinition[@"maxNumber"] doubleValue]] ;
                        break ;
                    }
                }

                if (subKeyMiniDefinition[@"minNumber"]) {
                    if ([keyValue[subKeyName] doubleValue] < [subKeyMiniDefinition[@"minNumber"] doubleValue]) {
                        errorMessage = [NSString stringWithFormat:@"field %@ of %@ must be >= %f", subKeyName, keyName, [subKeyMiniDefinition[@"minNumber"] doubleValue]] ;
                        break ;
                    }
                }

            }
            if (errorMessage) break ;
        }

        if ([keyValue isKindOfClass:[NSArray class]]) {
            BOOL isGood = YES ;
            if ([keyValue count] > 0) {
                for (NSUInteger i = 0 ; i < [keyValue count] ; i++) {
                    if (![keyValue[i] isKindOfClass:attributeDefinition[@"memberClass"]]) {
                        isGood = NO ;
                        break ;
                    } else if ([keyValue[i] isKindOfClass:[NSDictionary class]]) {
                        [keyValue[i] enumerateKeysAndObjectsUsingBlock:^(NSString *subKey, id obj, BOOL *stop) {
                            NSDictionary *subKeyDefinition = attributeDefinition[@"memberClassKeys"][subKey] ;
                            if (subKeyDefinition) {
                                validity = isValueValidForDictionary(subKey, obj, subKeyDefinition) ;
                            } else {
                                validity = attributeInvalid ;
                                errorMessage = [NSString stringWithFormat:@"%@ is not a valid subkey for a %@ value", subKey, attributeDefinition[@"memberLuaClass"]] ;
                            }
                            if (validity != attributeValid) *stop = YES ;
                        }] ;
                    }
                }
                if (!isGood) {
                    errorMessage = [NSString stringWithFormat:@"%@ must be an array of %@ values", keyName, attributeDefinition[@"memberLuaClass"]] ;
                    break ;
                }
            }
        }

        if ([keyName isEqualToString:@"textFont"]) {
            NSFont *testFont = [NSFont fontWithName:keyValue size:0.0] ;
            if (!testFont) {
                errorMessage = [NSString stringWithFormat:@"%@ is not a recognized font name", keyValue] ;
                break ;
            }
        }
    }
    if (errorMessage) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@", USERDATA_TAG, errorMessage]] ;
        validity = attributeInvalid ;
    }
    return validity ;
}

static attributeValidity isValueValidForAttribute(NSString *keyName, id keyValue) {
    NSDictionary      *attributeDefinition = languageDictionary[keyName] ;
    if (attributeDefinition) {
        return isValueValidForDictionary(keyName, keyValue, attributeDefinition) ;
    } else {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:%@ is not a valid canvas attribute", USERDATA_TAG, keyName]] ;
        return attributeInvalid ;
    }
}

static NSNumber *convertPercentageStringToNumber(NSString *stringValue) {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.locale = [NSLocale currentLocale] ;

    formatter.numberStyle = NSNumberFormatterDecimalStyle ;
    NSNumber *tmpValue = [formatter numberFromString:stringValue] ;
    if (!tmpValue) {
        formatter.numberStyle = NSNumberFormatterPercentStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
    }
    // just to be sure, let's also check with the en_US locale
    if (!tmpValue) {
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"] ;
        formatter.numberStyle = NSNumberFormatterDecimalStyle ;
        tmpValue = [formatter numberFromString:stringValue] ;
        if (!tmpValue) {
            formatter.numberStyle = NSNumberFormatterPercentStyle ;
            tmpValue = [formatter numberFromString:stringValue] ;
        }
    }
    return tmpValue ;
}

static inline NSRect RectWithFlippedYCoordinate(NSRect theRect) {
    return NSMakeRect(theRect.origin.x,
                      [[NSScreen screens][0] frame].size.height - theRect.origin.y - theRect.size.height,
                      theRect.size.width,
                      theRect.size.height) ;
}

static int canvas_orderHelper(lua_State *L, NSWindowOrderingMode mode) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK | LS_TVARARG] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if (parentIsWindow(canvasView)) {
        HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

        NSInteger       relativeTo = 0 ;

        if (lua_gettop(L) > 1) {
            if (lua_type(L, 2) == LUA_TNIL) {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNIL, LS_TBREAK] ;
            } else {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TUSERDATA, USERDATA_TAG,
                                LS_TBREAK] ;
                HSCanvasView   *otherView   = [skin luaObjectAtIndex:2 toClass:"HSCanvasView"] ;
                HSCanvasWindow *otherWindow = (HSCanvasWindow *)otherView.window ;
                if (otherWindow) relativeTo = [otherWindow windowNumber] ;
            }
        }

        if (canvasWindow) [canvasWindow orderWindow:mode relativeTo:relativeTo] ;

        lua_pushvalue(L, 1);
    } else {
        return luaL_argerror(L, 1, "method unavailable for canvas as a subview") ;
    }

    return 1 ;
}

static int userdata_gc(lua_State* L) ;

#pragma mark -
@implementation HSCanvasWindow
// Apple's stupid API change gave this an enum name (finally) in 10.12, but clang complains about using the underlying
// type directly, which we have to do to maintain Xcode 7 compilability, so to keep Xcode 8 quite... this:
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Woverriding-method-mismatch"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmismatched-parameter-types"
- (instancetype)initWithContentRect:(NSRect)contentRect
                          styleMask:(NSUInteger)windowStyle
                            backing:(NSBackingStoreType)bufferingType
                              defer:(BOOL)deferCreation
#pragma clang diagnostic pop
#pragma clang diagnostic pop
{

    if (!(isfinite(contentRect.origin.x) && isfinite(contentRect.origin.y) && isfinite(contentRect.size.height) && isfinite(contentRect.size.width))) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:coordinates must be finite numbers", USERDATA_TAG]];
        return nil;
    }

    self = [super initWithContentRect:contentRect
                            styleMask:windowStyle
                              backing:bufferingType
                                defer:deferCreation];
    if (self) {
        [self setDelegate:self];

        [self setFrameOrigin:RectWithFlippedYCoordinate(contentRect).origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor    = [NSColor clearColor];
        self.opaque             = NO;
        self.hasShadow          = NO;
        self.ignoresMouseEvents = YES;
        self.restorable         = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior  = NSWindowAnimationBehaviorNone;
        self.level              = NSScreenSaverWindowLevel;
        _subroleOverride        = nil ;
    }
    return self;
}

- (NSString *)accessibilitySubrole {
    NSString *defaultSubrole = [super accessibilitySubrole] ;
    NSString *customSubrole  = [defaultSubrole stringByAppendingString:@".Hammerspoon"] ;

    if (_subroleOverride) {
        if ([_subroleOverride isEqualToString:@""]) {
            return defaultCustomSubRole ? defaultSubrole : customSubrole ;
        } else {
            return _subroleOverride ;
        }
    } else {
        return defaultCustomSubRole ? customSubrole : defaultSubrole ;
    }
}

- (BOOL)canBecomeKeyWindow {
    __block BOOL allowKey = NO ;
    if (self.contentView && [self.contentView isKindOfClass:[HSCanvasView class]]) {
        NSArray *elementList = ((HSCanvasView *)self.contentView).elementList ;
        [elementList enumerateObjectsUsingBlock:^(NSDictionary *element, __unused NSUInteger idx, BOOL *stop) {
            if (element[@"canvas"] && [element[@"canvas"] respondsToSelector:@selector(canBecomeKeyView)]) {
                allowKey = [element[@"canvas"] canBecomeKeyView] ;
                *stop = YES ;
            }
        }] ;
    }
    return allowKey ;
}

#pragma mark - NSWindowDelegate Methods

- (BOOL)windowShouldClose:(id __unused)sender {
    return NO;
}

#pragma mark - Window Animation Methods

- (void)fadeIn:(NSTimeInterval)fadeTime {
    CGFloat alphaSetting = self.alphaValue ;
    [self setAlphaValue:0.0];
    [self makeKeyAndOrderFront:nil];
    [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[self animator] setAlphaValue:alphaSetting];
    [NSAnimationContext endGrouping];
}

- (void)fadeOut:(NSTimeInterval)fadeTime andDelete:(BOOL)deleteCanvas withState:(lua_State *)L {
    CGFloat alphaSetting = self.alphaValue ;
    [NSAnimationContext beginGrouping];
    __weak HSCanvasWindow *bself = self; // in ARC, __block would increase retain count
    [[NSAnimationContext currentContext] setDuration:fadeTime];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            // unlikely that bself will go to nil after this starts, but this keeps the warnings down from [-Warc-repeated-use-of-weak]
            HSCanvasWindow *mySelf = bself ;
            if (mySelf && (((HSCanvasView *)mySelf.contentView).selfRef != LUA_NOREF)) {
                if (deleteCanvas) {
                    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
                    //                   lua_State *L = [skin L] ;
                    lua_pushcfunction(L, userdata_gc) ;
                    [skin pushLuaRef:refTable ref:((HSCanvasView *)mySelf.contentView).selfRef] ;
                    // FIXME: Can we switch this lua_pcall() to a LuaSkin protectedCallAndError?
                    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
                        [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete (with fade) method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
                        lua_pop(L, 1) ;
                        [mySelf close] ;  // the least we can do is close the canvas if an error occurs with __gc
                    }
                } else {
                    [mySelf orderOut:nil];
                    [mySelf setAlphaValue:alphaSetting];
                }
            }
        });
    }];
    [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}
@end

#pragma mark -
@implementation HSCanvasView
- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        _selfRef               = LUA_NOREF ;
        _wrapperWindow         = nil ;

        _mouseCallbackRef      = LUA_NOREF;
        _draggingCallbackRef   = LUA_NOREF;
        _canvasDefaults        = [[NSMutableDictionary alloc] init] ;
        _elementList           = [[NSMutableArray alloc] init] ;
        _elementBounds         = [[NSMutableArray alloc] init] ;
        _canvasTransform       = [NSAffineTransform transform] ;
        _imageAnimations       = [NSMapTable weakToStrongObjectsMapTable] ;

        _canvasMouseDown       = NO ;
        _canvasMouseUp         = NO ;
        _canvasMouseEnterExit  = NO ;
        _canvasMouseMove       = NO ;

        _mouseTracking         = NO ;
        _previousTrackedIndex  = NSNotFound ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wassign-enum"
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:frameRect
                                                           options:NSTrackingMouseMoved |
                                                                   NSTrackingMouseEnteredAndExited |
                                                                   NSTrackingActiveAlways |
                                                                   NSTrackingInVisibleRect
                                                             owner:self
                                                          userInfo:nil]] ;
#pragma clang diagnostic pop
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (BOOL)acceptsFirstMouse:(__unused NSEvent *)theEvent {
    if (self.window == nil) return NO;
    return !self.window.ignoresMouseEvents;
}

- (BOOL)canBecomeKeyView {
    __block BOOL allowKey = NO ;
    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, __unused NSUInteger idx, BOOL *stop) {
        if (element[@"canvas"] && [element[@"canvas"] respondsToSelector:@selector(canBecomeKeyView)]) {
            allowKey = [element[@"canvas"] canBecomeKeyView] ;
            *stop = YES ;
        }
    }] ;
    return allowKey ;
}

- (void)mouseMoved:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        __block NSUInteger targetIndex = NSNotFound ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [box[@"index"] unsignedIntegerValue] ;
            if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:elementIdx] boolValue] || [[self getElementValueFor:@"trackMouseMove" atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                BOOL isView = [[self getElementValueFor:@"type" atIndex:elementIdx] isEqualToString:@"canvas"] ;
                actualPoint = isView ? local_point : [pointTransform transformPoint:local_point] ;
                if (box[@"imageByBounds"] && ![box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                            targetIndex = idx ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [box[@"frame"] rectValue])) || (box[@"path"] && [box[@"path"] containsPoint:actualPoint])) {
                    targetIndex = idx ;
                    *stop = YES ;
                }
            }
        }] ;

        NSUInteger realTargetIndex = (targetIndex != NSNotFound) ?
                    [_elementBounds[targetIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
        NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;

        if (_previousTrackedIndex == targetIndex) {
            if ((targetIndex != NSNotFound) && [[self getElementValueFor:@"trackMouseMove" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
            }
        } else {
            if ((_previousTrackedIndex != NSNotFound) && [[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
            if (targetIndex != NSNotFound) {
                id targetID = [self getElementValueFor:@"id" atIndex:realTargetIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realTargetIndex + 1) ;
                if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseEnter" for:targetID at:local_point] ;
                } else if ([[self getElementValueFor:@"trackMouseMove" atIndex:realTargetIndex] boolValue]) {
                    [self doMouseCallback:@"mouseMove" for:targetID at:local_point] ;
                }
                if (_canvasMouseEnterExit && (_previousTrackedIndex == NSNotFound)) {
                    [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
                }
            }
        }

        if ((_canvasMouseEnterExit || _canvasMouseMove) && (targetIndex == NSNotFound)) {
            if (_previousTrackedIndex == NSNotFound && _canvasMouseMove) {
                [self doMouseCallback:@"mouseMove" for:@"_canvas_" at:local_point] ;
            } else if (_previousTrackedIndex != NSNotFound && _canvasMouseEnterExit) {
                [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
            }
        }
        _previousTrackedIndex = targetIndex ;
    }
}

- (void)mouseEntered:(NSEvent *)theEvent {
    if ((_mouseCallbackRef != LUA_NOREF) && _canvasMouseEnterExit) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];

        [self doMouseCallback:@"mouseEnter" for:@"_canvas_" at:local_point] ;
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    BOOL canvasMouseEvents = _canvasMouseEnterExit || _canvasMouseMove ;

    if ((_mouseCallbackRef != LUA_NOREF) && (_mouseTracking || canvasMouseEvents)) {
        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
        if (_previousTrackedIndex != NSNotFound) {
            NSUInteger realPrevIndex = (_previousTrackedIndex != NSNotFound) ?
                    [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue]  : NSNotFound ;
            if ([[self getElementValueFor:@"trackMouseEnterExit" atIndex:realPrevIndex] boolValue]) {
                id targetID = [self getElementValueFor:@"id" atIndex:realPrevIndex onlyIfSet:YES] ;
                if (!targetID) targetID = @(realPrevIndex + 1) ;
                [self doMouseCallback:@"mouseExit" for:targetID at:local_point] ;
            }
        }
        if (_canvasMouseEnterExit) {
            [self doMouseCallback:@"mouseExit" for:@"_canvas_" at:local_point] ;
        }
    }
    _previousTrackedIndex = NSNotFound ;
}

- (void)doMouseCallback:(NSString *)message for:(id)elementIdentifier at:(NSPoint)location {
    if (elementIdentifier && _mouseCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_mouseCallbackRef];
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        [skin pushNSObject:elementIdentifier] ;
        lua_pushnumber(skin.L, location.x) ;
        lua_pushnumber(skin.L, location.y) ;
        [skin protectedCallAndError:[NSString stringWithFormat:@"hs.canvas:clickCallback for %@", message] nargs:5 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

// NOTE: Do we need/want this?
- (void)subviewCallback:(id)sender {
    if (_mouseCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:_mouseCallbackRef];
        [skin pushNSObject:self] ;
        [skin pushNSObject:@"_subview_"] ;
        [skin pushNSObject:sender] ;
        [skin protectedCallAndError:@"hs.canvas:buttonCallback" nargs:3 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)mouseDown:(NSEvent *)theEvent {
    [NSApp preventWindowOrdering];
    if (_mouseCallbackRef != LUA_NOREF) {
        BOOL isDown = (theEvent.type == NSEventTypeLeftMouseDown)  ||
                      (theEvent.type == NSEventTypeRightMouseDown) ||
                      (theEvent.type == NSEventTypeOtherMouseDown) ;

        NSPoint event_location = theEvent.locationInWindow;
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
//         [LuaSkin logWarn:[NSString stringWithFormat:@"mouse click at (%f, %f)", local_point.x, local_point.y]] ;

        __block id targetID = nil ;
        __block NSPoint actualPoint = local_point ;

        [_elementBounds enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(NSDictionary *box, __unused NSUInteger idx, BOOL *stop) {
            NSUInteger elementIdx  = [box[@"index"] unsignedIntegerValue] ;
            if ([[self getElementValueFor:(isDown ? @"trackMouseDown" : @"trackMouseUp") atIndex:elementIdx] boolValue]) {
                NSAffineTransform *pointTransform = [self->_canvasTransform copy] ;
                [pointTransform appendTransform:[self getElementValueFor:@"transformation" atIndex:elementIdx]] ;
                [pointTransform invert] ;
                BOOL isView = [[self getElementValueFor:@"type" atIndex:elementIdx] isEqualToString:@"canvas"] ;
                actualPoint = isView ? local_point : [pointTransform transformPoint:local_point] ;                actualPoint = [pointTransform transformPoint:local_point] ;
                if (box[@"imageByBounds"] && ![box[@"imageByBounds"] boolValue]) {
                    NSImage *theImage = self->_elementList[elementIdx][@"image"] ;
                    if (theImage) {
                        NSRect hitRect = NSMakeRect(actualPoint.x, actualPoint.y, 1.0, 1.0) ;
                        NSRect imageRect = [box[@"frame"] rectValue] ;
                        if ([theImage hitTestRect:hitRect withImageDestinationRect:imageRect
                                                                           context:nil
                                                                             hints:nil
                                                                           flipped:YES]) {
                        targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                        if (!targetID) targetID = @(elementIdx + 1) ;
                            *stop = YES ;
                        }
                    }
                } else if ((box[@"frame"] && NSPointInRect(actualPoint, [box[@"frame"] rectValue])) || (box[@"path"] && [box[@"path"] containsPoint:actualPoint])) {
                    targetID = [self getElementValueFor:@"id" atIndex:elementIdx onlyIfSet:YES] ;
                    if (!targetID) targetID = @(elementIdx + 1) ;
                    *stop = YES ;
                }
                if (*stop) {
                    if (isDown && [[self getElementValueFor:@"trackMouseDown" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseDown" for:targetID at:local_point] ;
                    }
                    if (!isDown && [[self getElementValueFor:@"trackMouseUp" atIndex:elementIdx] boolValue]) {
                        [self doMouseCallback:@"mouseUp" for:targetID at:local_point] ;
                    }
                }
            }
        }] ;

        if (!targetID) {
            if (isDown && _canvasMouseDown) {
                [self doMouseCallback:@"mouseDown" for:@"_canvas_" at:local_point] ;
            } else if (!isDown && _canvasMouseUp) {
                [self doMouseCallback:@"mouseUp" for:@"_canvas_" at:local_point] ;
            }
        }
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)otherMouseDown:(NSEvent *)theEvent { [self mouseDown:theEvent] ; }
- (void)mouseUp:(NSEvent *)theEvent        { [self mouseDown:theEvent] ; }
- (void)rightMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }
- (void)otherMouseUp:(NSEvent *)theEvent   { [self mouseDown:theEvent] ; }

#ifdef VIEW_DEBUG
- (void)didAddSubview:(NSView *)subview {
    [LuaSkin logInfo:[NSString stringWithFormat:@"%s - didAddSubview for %@", USERDATA_TAG, subview]] ;
}
#endif

- (void)viewDidMoveToSuperview {
    if (!self.superview && self.wrapperWindow) {
    // stick us back into our wrapper window if we've been released from another canvas
        self.frame = self.wrapperWindow.contentView.bounds ;
        self.wrapperWindow.contentView = self ;
    }
}

- (void)willRemoveSubview:(NSView *)subview {
#ifdef VIEW_DEBUG
    [LuaSkin logInfo:[NSString stringWithFormat:@"%s - willRemoveSubview for %@", USERDATA_TAG, subview]] ;
#endif

    __block BOOL viewFound = NO ;
    [_elementList enumerateObjectsUsingBlock:^(NSMutableDictionary *element, __unused NSUInteger idx, BOOL *stop){
        if ([element[@"canvas"] isEqualTo:subview]) {
            [element removeObjectForKey:@"canvas"] ;
            viewFound = YES ;
            *stop = YES ;
        }
    }] ;
    if (!viewFound) [LuaSkin logError:@"view removed from canvas superview does not belong to any known canvas element"] ;
}

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx {
    NSDictionary *frame = [self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
    NSRect frameRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                  [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;
    return [self pathForElementAtIndex:idx withFrame:frameRect] ;
}

- (NSBezierPath *)pathForElementAtIndex:(NSUInteger)idx withFrame:(NSRect)frameRect {
    NSBezierPath *elementPath = nil ;
    NSString     *elementType = [self getElementValueFor:@"type" atIndex:idx] ;

#pragma mark - ARC
    if ([elementType isEqualToString:@"arc"]) {
        NSDictionary *center = [self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
        CGFloat cx = [center[@"x"] doubleValue] ;
        CGFloat cy = [center[@"y"] doubleValue] ;
        CGFloat r  = [[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
        NSPoint myCenterPoint = NSMakePoint(cx, cy) ;
        elementPath = [NSBezierPath bezierPath];
        CGFloat startAngle = [[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
        CGFloat endAngle   = [[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
        BOOL    arcDir     = [[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
        BOOL    arcLegs    = [[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
        if (arcLegs) [elementPath moveToPoint:myCenterPoint] ;
        [elementPath appendBezierPathWithArcWithCenter:myCenterPoint
                                                radius:r
                                            startAngle:startAngle
                                              endAngle:endAngle
                                             clockwise:!arcDir // because our canvas is flipped, we have to reverse this
        ] ;
        if (arcLegs) [elementPath lineToPoint:myCenterPoint] ;
    } else
#pragma mark - CIRCLE
    if ([elementType isEqualToString:@"circle"]) {
        NSDictionary *center = [self getElementValueFor:@"center" atIndex:idx resolvePercentages:YES] ;
        CGFloat cx = [center[@"x"] doubleValue] ;
        CGFloat cy = [center[@"y"] doubleValue] ;
        CGFloat r  = [[self getElementValueFor:@"radius" atIndex:idx resolvePercentages:YES] doubleValue] ;
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:NSMakeRect(cx - r, cy - r, r * 2, r * 2)] ;
    } else
#pragma mark - ELLIPTICALARC
    if ([elementType isEqualToString:@"ellipticalArc"]) {
        CGFloat cx     = frameRect.origin.x + frameRect.size.width / 2 ;
        CGFloat cy     = frameRect.origin.y + frameRect.size.height / 2 ;
        CGFloat r      = frameRect.size.width / 2 ;

        NSAffineTransform *moveTransform = [NSAffineTransform transform] ;
        [moveTransform translateXBy:cx yBy:cy] ;
        NSAffineTransform *scaleTransform = [NSAffineTransform transform] ;
        [scaleTransform scaleXBy:1.0 yBy:(frameRect.size.height / frameRect.size.width)] ;
        NSAffineTransform *finalTransform = [[NSAffineTransform alloc] initWithTransform:scaleTransform] ;
        [finalTransform appendTransform:moveTransform] ;
        elementPath = [NSBezierPath bezierPath];
        CGFloat startAngle = [[self getElementValueFor:@"startAngle" atIndex:idx] doubleValue] - 90 ;
        CGFloat endAngle   = [[self getElementValueFor:@"endAngle" atIndex:idx] doubleValue] - 90 ;
        BOOL    arcDir     = [[self getElementValueFor:@"arcClockwise" atIndex:idx] boolValue] ;
        BOOL    arcLegs    = [[self getElementValueFor:@"arcRadii" atIndex:idx] boolValue] ;
        if (arcLegs) [elementPath moveToPoint:NSZeroPoint] ;
        [elementPath appendBezierPathWithArcWithCenter:NSZeroPoint
                                                radius:r
                                            startAngle:startAngle
                                              endAngle:endAngle
                                             clockwise:!arcDir // because our canvas is flipped, we have to reverse this
        ] ;
        if (arcLegs) [elementPath lineToPoint:NSZeroPoint] ;
        elementPath = [finalTransform transformBezierPath:elementPath] ;
    } else
#pragma mark - OVAL
    if ([elementType isEqualToString:@"oval"]) {
        elementPath = [NSBezierPath bezierPath];
        [elementPath appendBezierPathWithOvalInRect:frameRect] ;
    } else
#pragma mark - RECTANGLE
    if ([elementType isEqualToString:@"rectangle"]) {
        elementPath = [NSBezierPath bezierPath];
        NSDictionary *roundedRect = [self getElementValueFor:@"roundedRectRadii" atIndex:idx] ;
        [elementPath appendBezierPathWithRoundedRect:frameRect
                                          xRadius:[roundedRect[@"xRadius"] doubleValue]
                                          yRadius:[roundedRect[@"yRadius"] doubleValue]] ;
    } else
#pragma mark - POINTS
    if ([elementType isEqualToString:@"points"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = [self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, __unused NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            [elementPath appendBezierPathWithRect:NSMakeRect([xNumber doubleValue], [yNumber doubleValue], 1.0, 1.0)] ;
        }] ;
    } else
#pragma mark - SEGMENTS
    if ([elementType isEqualToString:@"segments"]) {
        elementPath = [NSBezierPath bezierPath];
        NSArray *coordinates = [self getElementValueFor:@"coordinates" atIndex:idx resolvePercentages:YES] ;

        [coordinates enumerateObjectsUsingBlock:^(NSDictionary *aPoint, NSUInteger idx2, __unused BOOL *stop2) {
            NSNumber *xNumber   = aPoint[@"x"] ;
            NSNumber *yNumber   = aPoint[@"y"] ;
            NSNumber *c1xNumber = aPoint[@"c1x"] ;
            NSNumber *c1yNumber = aPoint[@"c1y"] ;
            NSNumber *c2xNumber = aPoint[@"c2x"] ;
            NSNumber *c2yNumber = aPoint[@"c2y"] ;
            BOOL goodForCurve = (c1xNumber) && (c1yNumber) && (c2xNumber) && (c2yNumber) ;
            if (idx2 == 0) {
                [elementPath moveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else if (!goodForCurve) {
                [elementPath lineToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])] ;
            } else {
                [elementPath curveToPoint:NSMakePoint([xNumber doubleValue], [yNumber doubleValue])
                            controlPoint1:NSMakePoint([c1xNumber doubleValue], [c1yNumber doubleValue])
                            controlPoint2:NSMakePoint([c2xNumber doubleValue], [c2yNumber doubleValue])] ;
            }
        }] ;
        if ([[self getElementValueFor:@"closed" atIndex:idx] boolValue]) {
            [elementPath closePath] ;
        }
    }

    return elementPath ;
}

- (void)drawRect:(__unused NSRect)rect {
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];
    [gc saveGraphicsState];

    [_canvasTransform concat] ;

    [NSBezierPath setDefaultLineWidth:[[self getDefaultValueFor:@"strokeWidth" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultMiterLimit:[[self getDefaultValueFor:@"miterLimit" onlyIfSet:NO] doubleValue]] ;
    [NSBezierPath setDefaultFlatness:[[self getDefaultValueFor:@"flatness" onlyIfSet:NO] doubleValue]] ;

    NSString *LJS = [self getDefaultValueFor:@"strokeJoinStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[STROKE_JOIN_STYLES[LJS] unsignedIntValue]] ;

    NSString *LCS = [self getDefaultValueFor:@"strokeCapStyle" onlyIfSet:NO] ;
    [NSBezierPath setDefaultLineJoinStyle:[STROKE_CAP_STYLES[LCS] unsignedIntValue]] ;

    NSString *WR = [self getDefaultValueFor:@"windingRule" onlyIfSet:NO] ;
    [NSBezierPath setDefaultWindingRule:[WINDING_RULES[WR] unsignedIntValue]] ;

    NSString *CS = [self getDefaultValueFor:@"compositeRule" onlyIfSet:NO] ;
    gc.compositingOperation = [COMPOSITING_TYPES[CS] unsignedIntValue] ;

    [[self getDefaultValueFor:@"antialias" onlyIfSet:NO] boolValue] ;
    [[self getDefaultValueFor:@"fillColor" onlyIfSet:NO] setFill] ;
    [[self getDefaultValueFor:@"strokeColor" onlyIfSet:NO] setStroke] ;

    // because of changes to the elements, skip actions, etc, previous tracking info may change...
    NSUInteger previousTrackedRealIndex = NSNotFound ;
    if (_previousTrackedIndex != NSNotFound) {
        previousTrackedRealIndex = [_elementBounds[_previousTrackedIndex][@"index"] unsignedIntegerValue] ;
        _previousTrackedIndex = NSNotFound ;
    }

    _elementBounds = [[NSMutableArray alloc] init] ;

    // renderPath needs to persist through iterations, so define it here
    __block NSBezierPath *renderPath ;
    __block BOOL         clippingModified = NO ;
    __block BOOL         needMouseTracking = NO ;

    [_elementList enumerateObjectsUsingBlock:^(NSDictionary *element, NSUInteger idx, __unused BOOL *stop) {
        NSBezierPath *elementPath ;
        NSString     *elementType = element[@"type"] ;
        NSString     *action      = [self getElementValueFor:@"action" atIndex:idx] ;

        if (![action isEqualTo:@"skip"]) {
            if (!needMouseTracking) {
                needMouseTracking = [[self getElementValueFor:@"trackMouseEnterExit" atIndex:idx] boolValue] || [[self getElementValueFor:@"trackMouseMove" atIndex:idx] boolValue] ;
            }

            BOOL wasClippingChanged = NO ; // necessary to keep graphicsState stack properly ordered

            [gc saveGraphicsState] ;

            BOOL hasShadow = [[self getElementValueFor:@"withShadow" atIndex:idx] boolValue] ;
            if (hasShadow) [(NSShadow *)[self getElementValueFor:@"shadow" atIndex:idx] set] ;

            NSNumber *shouldAntialias = [self getElementValueFor:@"antialias" atIndex:idx onlyIfSet:YES] ;
            if (shouldAntialias) gc.shouldAntialias = [shouldAntialias boolValue] ;

            NSString *compositingString = [self getElementValueFor:@"compositeRule" atIndex:idx onlyIfSet:YES] ;
            if (compositingString) gc.compositingOperation = [COMPOSITING_TYPES[compositingString] unsignedIntValue] ;

            NSColor *fillColor = [self getElementValueFor:@"fillColor" atIndex:idx onlyIfSet:YES] ;
            if (fillColor) [fillColor setFill] ;

            NSColor *strokeColor = [self getElementValueFor:@"strokeColor" atIndex:idx onlyIfSet:YES] ;
            if (strokeColor) [strokeColor setStroke] ;

            NSAffineTransform *elementTransform = [self getElementValueFor:@"transformation" atIndex:idx] ;
            if (elementTransform) [elementTransform concat] ;

            NSDictionary *frame = [self getElementValueFor:@"frame" atIndex:idx resolvePercentages:YES] ;
            NSRect frameRect = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                          [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;

//             // Converts the corners of a specified rectangle to lie on the center of device pixels, which is useful in compensating for rendering overscanning when the coordinate system has been scaled.
//             frameRect = [self centerScanRect:frameRect] ;

            elementPath = [self pathForElementAtIndex:idx withFrame:frameRect] ;

            // First, if it's not a path, make sure it's not an element which doesn't have a path...

            if (!elementPath) {
    #pragma mark - IMAGE
                if ([elementType isEqualToString:@"image"]) {
                    NSImage *theImage = self->_elementList[idx][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        [self drawImage:theImage
                                atIndex:idx
                                 inRect:frameRect
                              operation:[COMPOSITING_TYPES[CS] unsignedIntValue]] ;
                        [self->_elementBounds addObject:@{
                            @"index"         : @(idx),
                            @"frame"         : [NSValue valueWithRect:frameRect],
                            @"imageByBounds" : [self getElementValueFor:@"trackMouseByBounds" atIndex:idx]
                        }] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - TEXT
                if ([elementType isEqualToString:@"text"]) {
                    id textEntry = [self getElementValueFor:@"text" atIndex:idx onlyIfSet:YES] ;
                    if (!textEntry) {
                        textEntry = @"" ;
                    } else if([textEntry isKindOfClass:[NSNumber class]]) {
                        textEntry = [(NSNumber *)textEntry stringValue] ;
                    }

                    if ([textEntry isKindOfClass:[NSString class]]) {
                        NSString *myFont = [self getElementValueFor:@"textFont" atIndex:idx onlyIfSet:NO] ;
                        NSNumber *mySize = [self getElementValueFor:@"textSize" atIndex:idx onlyIfSet:NO] ;
                        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
                        NSString *alignment = [self getElementValueFor:@"textAlignment" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.alignment = [TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
                        NSString *wrap = [self getElementValueFor:@"textLineBreak" atIndex:idx onlyIfSet:NO] ;
                        theParagraphStyle.lineBreakMode = [TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
                        NSDictionary *attributes = @{
                            NSForegroundColorAttributeName : [self getElementValueFor:@"textColor" atIndex:idx onlyIfSet:NO],
                            NSFontAttributeName            : [NSFont fontWithName:myFont size:[mySize doubleValue]],
                            NSParagraphStyleAttributeName  : theParagraphStyle,
                        } ;

                        [(NSString *)textEntry drawInRect:frameRect withAttributes:attributes] ;
                    } else {
                        [(NSAttributedString *)textEntry drawInRect:frameRect] ;
                    }
                    [self->_elementBounds addObject:@{
                        @"index" : @(idx),
                        @"frame" : [NSValue valueWithRect:frameRect]
                    }] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - VIEW
                if ([elementType isEqualToString:@"canvas"]) {
                    NSView *externalView = [self getElementValueFor:@"canvas" atIndex:idx onlyIfSet:NO] ;
                    if ([externalView isKindOfClass:[NSView class]]) {
                        externalView.needsDisplay = YES ;
                        if (externalView.hidden) externalView.hidden = NO ;
                        NSNumber *alpha = [self getElementValueFor:@"canvasAlpha" atIndex:idx onlyIfSet:YES] ;
                        if (alpha) externalView.alphaValue = [alpha doubleValue] ;
                        [externalView setFrame:frameRect] ;
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"frame" : [NSValue valueWithRect:frameRect]
                        }] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else
    #pragma mark - RESETCLIP
                if ([elementType isEqualToString:@"resetClip"]) {
                    [gc restoreGraphicsState] ; // from beginning of enumeration
                    wasClippingChanged = YES ;
                    if (clippingModified) {
                        [gc restoreGraphicsState] ; // from clip action
                        clippingModified = NO ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - un-nested resetClip at index %lu", USERDATA_TAG, idx + 1]] ;
                    }
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                } else {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized type %@ at index %lu", USERDATA_TAG, elementType, idx + 1]] ;
                    elementPath = nil ; // shouldn't be necessary, but lets be explicit
                }
            }
            // Now, if it's still not a path, we don't render it.  But if it is...

    #pragma mark - Render Logic
            if (elementPath) {
                NSNumber *miterLimit = [self getElementValueFor:@"miterLimit" atIndex:idx onlyIfSet:YES] ;
                if (miterLimit) elementPath.miterLimit = [miterLimit doubleValue] ;

                NSNumber *flatness = [self getElementValueFor:@"flatness" atIndex:idx onlyIfSet:YES] ;
                if (flatness) elementPath.flatness = [flatness doubleValue] ;

                if ([[self getElementValueFor:@"flattenPath" atIndex:idx] boolValue]) {
                    elementPath = elementPath.bezierPathByFlatteningPath ;
                }
                if ([[self getElementValueFor:@"reversePath" atIndex:idx] boolValue]) {
                    elementPath = elementPath.bezierPathByReversingPath ;
                }

                NSString *windingRule = [self getElementValueFor:@"windingRule" atIndex:idx onlyIfSet:YES] ;
                if (windingRule) elementPath.windingRule = [WINDING_RULES[windingRule] unsignedIntValue] ;

                if (renderPath) {
                    [renderPath appendBezierPath:elementPath] ;
                } else {
                    renderPath = elementPath ;
                }

                if ([action isEqualToString:@"clip"]) {
                    [gc restoreGraphicsState] ; // from beginning of enumeration
                    wasClippingChanged = YES ;
                    if (!clippingModified) {
                        [gc saveGraphicsState] ;
                        clippingModified = YES ;
                    }
                    [renderPath addClip] ;
                    renderPath = nil ;

                } else if ([action isEqualToString:@"fill"] || [action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {

                    BOOL clipToPath = [[self getElementValueFor:@"clipToPath" atIndex:idx] boolValue] ;
                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc saveGraphicsState] ;
                        [renderPath addClip] ;
                    }

                    if (![elementType isEqualToString:@"points"] && ([action isEqualToString:@"fill"] || [action isEqualToString:@"strokeAndFill"])) {
                        NSString     *fillGradient   = [self getElementValueFor:@"fillGradient" atIndex:idx] ;
                        if (![fillGradient isEqualToString:@"none"] && ![renderPath isEmpty]) {
                            NSArray *gradientColors = [self getElementValueFor:@"fillGradientColors" atIndex:idx] ;
                            NSGradient* gradient = [[NSGradient alloc] initWithColors:gradientColors];
                            if ([fillGradient isEqualToString:@"linear"]) {
                                [gradient drawInBezierPath:renderPath angle:[[self getElementValueFor:@"fillGradientAngle" atIndex:idx] doubleValue]] ;
                            } else if ([fillGradient isEqualToString:@"radial"]) {
                                NSDictionary *centerPoint = [self getElementValueFor:@"fillGradientCenter" atIndex:idx] ;
                                [gradient drawInBezierPath:renderPath
                                    relativeCenterPosition:NSMakePoint([centerPoint[@"x"] doubleValue], [centerPoint[@"y"] doubleValue])] ;
                            }
                        } else {
                            [renderPath fill] ;
                        }
                    }

                    if ([action isEqualToString:@"stroke"] || [action isEqualToString:@"strokeAndFill"]) {
                        NSNumber *strokeWidth = [self getElementValueFor:@"strokeWidth" atIndex:idx onlyIfSet:YES] ;
                        if (strokeWidth) renderPath.lineWidth  = [strokeWidth doubleValue] ;

                        NSString *lineJoinStyle = [self getElementValueFor:@"strokeJoinStyle" atIndex:idx onlyIfSet:YES] ;
                        if (lineJoinStyle) renderPath.lineJoinStyle = [STROKE_JOIN_STYLES[lineJoinStyle] unsignedIntValue] ;

                        NSString *lineCapStyle = [self getElementValueFor:@"strokeCapStyle" atIndex:idx onlyIfSet:YES] ;
                        if (lineCapStyle) renderPath.lineCapStyle = [STROKE_CAP_STYLES[lineCapStyle] unsignedIntValue] ;

                        NSArray *strokeDashes = [self getElementValueFor:@"strokeDashPattern" atIndex:idx] ;
                        if ([strokeDashes count] > 0) {
                            NSUInteger count = [strokeDashes count] ;
                            CGFloat    phase = [[self getElementValueFor:@"strokeDashPhase" atIndex:idx] doubleValue] ;
                            CGFloat *pattern ;
                            pattern = (CGFloat *)malloc(sizeof(CGFloat) * count) ;
                            if (pattern) {
                                for (NSUInteger i = 0 ; i < count ; i++) {
                                    pattern[i] = [strokeDashes[i] doubleValue] ;
                                }
                                [renderPath setLineDash:pattern count:(NSInteger)count phase:phase];
                                free(pattern) ;
                            }
                        }

                        [renderPath stroke] ;
                    }

                    if ([CLOSED containsObject:elementType] && clipToPath) {
                        [gc restoreGraphicsState] ;
                    }

                    if ([[self getElementValueFor:@"trackMouseByBounds" atIndex:idx] boolValue]) {
                        NSRect objectBounds = NSZeroRect ;
                        if (![renderPath isEmpty]) objectBounds = [renderPath bounds] ;
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"frame"  : [NSValue valueWithRect:objectBounds],
                        }] ;
                    } else {
                        [self->_elementBounds addObject:@{
                            @"index" : @(idx),
                            @"path"  : renderPath,
                        }] ;
                    }
                    renderPath = nil ;
                } else if (![action isEqualToString:@"build"]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:drawRect - unrecognized action %@ at index %lu", USERDATA_TAG, action, idx + 1]] ;
                }
            }
            // to keep nesting correct, this was already done if we adjusted clipping this round
            if (!wasClippingChanged) [gc restoreGraphicsState] ;

            if (idx == previousTrackedRealIndex) self->_previousTrackedIndex = [self->_elementBounds count] - 1 ;
        } else {
            if ([elementType isEqualToString:@"canvas"]) {
                NSView *externalView = [self getElementValueFor:@"canvas" atIndex:idx onlyIfSet:NO] ;
                if ([externalView isKindOfClass:[NSView class]]) {
                        if (!externalView.hidden) externalView.hidden = YES ;
                }
            }
        }
    }] ;

    if (clippingModified) [gc restoreGraphicsState] ; // balance our saves

    _mouseTracking = needMouseTracking ;
    [gc restoreGraphicsState];
}

// To facilitate the way frames and points are specified, we get our tables from lua with the LS_NSRawTables option... this forces rect-tables and point-tables to be just that - tables, but also prevents color tables, styledtext tables, and transform tables from being converted... so we add fixes for them here...
// Plus we allow some "laziness" on the part of the programmer to leave out __luaSkinType when crafting the tables by hand, either to make things cleaner/easier or for historical reasons...

- (id)massageKeyValue:(id)oldValue forKey:(NSString *)keyName withState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     lua_State *L = [skin L] ;

    id newValue = oldValue ; // assume we're not changing anything
//     [LuaSkin logWarn:[NSString stringWithFormat:@"keyname %@ (%@) oldValue is %@", keyName, NSStringFromClass([oldValue class]), [oldValue debugDescription]]] ;

    // fix "...Color" tables
    if ([keyName hasSuffix:@"Color"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSColor") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fillGradientColors is an array of colors
    } else if ([keyName isEqualToString:@"fillGradientColors"]) {
        newValue = [[NSMutableArray alloc] init] ;
        [(NSMutableArray *)oldValue enumerateObjectsUsingBlock:^(NSDictionary *anItem, NSUInteger idx, __unused BOOL *stop) {
            if ([anItem isKindOfClass:[NSDictionary class]]) {
                [skin pushNSObject:anItem] ;
                lua_pushstring(L, "NSColor") ;
                lua_setfield(L, -2, "__luaSkinType") ;
                anItem = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
            }
            if (anItem && [anItem isKindOfClass:[NSColor class]] && [(NSColor *)anItem colorUsingColorSpaceName:NSCalibratedRGBColorSpace]) {
                [(NSMutableArray *)newValue addObject:anItem] ;
            } else {
                [LuaSkin logWarn:[NSString stringWithFormat:@"%s:not a proper color at index %lu of fillGradientColor; using Black", USERDATA_TAG, idx + 1]] ;
                [(NSMutableArray *)newValue addObject:[NSColor blackColor]] ;
            }
        }] ;
        if ([(NSMutableArray *)newValue count] < 2) {
            [LuaSkin logWarn:[NSString stringWithFormat:@"%s:fillGradientColor requires at least 2 colors; using default", USERDATA_TAG]] ;
            newValue = [self getDefaultValueFor:keyName onlyIfSet:NO] ;
        }
    // fix NSAffineTransform table
    } else if ([keyName isEqualToString:@"transformation"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAffineTransform") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix NSShadow table
    } else if ([keyName isEqualToString:@"shadow"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSShadow") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // fix hs.styledText as Table
    } else if ([keyName isEqualToString:@"text"] && ([oldValue isKindOfClass:[NSDictionary class]] || [oldValue isKindOfClass:[NSArray class]])) {
        [skin pushNSObject:oldValue] ;
        lua_pushstring(L, "NSAttributedString") ;
        lua_setfield(L, -2, "__luaSkinType") ;
        newValue = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;

    // recurse into fields which have subfields to check those as well -- this should be done last in case the dictionary can be coerced into an object, like the color tables handled above
    } else if ([oldValue isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *blockValue = [[NSMutableDictionary alloc] init] ;
        [oldValue enumerateKeysAndObjectsUsingBlock:^(id blockKeyName, id valueForKey, __unused BOOL *stop) {
            [blockValue setObject:[self massageKeyValue:valueForKey forKey:blockKeyName withState:L] forKey:blockKeyName] ;
        }] ;
        newValue = blockValue ;
    }
//     [LuaSkin logWarn:[NSString stringWithFormat:@"newValue is %@", [newValue debugDescription]]] ;

    return newValue ;
}

- (id)getDefaultValueFor:(NSString *)keyName onlyIfSet:(BOOL)onlyIfSet {
    NSDictionary *attributeDefinition = languageDictionary[keyName] ;
    id result ;
    if (!attributeDefinition[@"default"]) {
        return nil ;
    } else if (_canvasDefaults[keyName]) {
        result = _canvasDefaults[keyName] ;
    } else if (!onlyIfSet) {
        result = attributeDefinition[@"default"] ;
    } else {
        result = nil ;
    }

    if ([[result class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        result = [result mutableCopy] ;
    } else if ([[result class] conformsToProtocol:@protocol(NSCopying)]) {
        result = [result copy] ;
    }
    return result ;
}

- (attributeValidity)setDefaultFor:(NSString *)keyName to:(id)keyValue withState:(lua_State *)L {
    attributeValidity validityStatus       = attributeInvalid ;
    if ([languageDictionary[keyName][@"nullable"] boolValue]) {
        keyValue = [self massageKeyValue:keyValue forKey:keyName withState:L] ;
        validityStatus = isValueValidForAttribute(keyName, keyValue) ;
        switch (validityStatus) {
            case attributeValid:
                _canvasDefaults[keyName] = keyValue ;
                break ;
            case attributeNulling:
                [_canvasDefaults removeObjectForKey:keyName] ;
                break ;
            case attributeInvalid:
                break ;
            default:
                [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
                break ;
        }
    }
    self.needsDisplay = YES ;
    return validityStatus ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:NO] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index onlyIfSet:(BOOL)onlyIfSet {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:NO onlyIfSet:onlyIfSet] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages {
    return [self getElementValueFor:keyName atIndex:index resolvePercentages:resolvePercentages onlyIfSet:NO] ;
}

- (id)getElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index resolvePercentages:(BOOL)resolvePercentages onlyIfSet:(BOOL)onlyIfSet {
    if (index >= [_elementList count]) return nil ;
    NSDictionary *elementAttributes = _elementList[index] ;
    id foundObject = elementAttributes[keyName] ? elementAttributes[keyName] : (onlyIfSet ? nil : [self getDefaultValueFor:keyName onlyIfSet:NO]) ;
    if ([[foundObject class] conformsToProtocol:@protocol(NSMutableCopying)]) {
        foundObject = [foundObject mutableCopy] ;
    } else if ([[foundObject class] conformsToProtocol:@protocol(NSCopying)]) {
        foundObject = [foundObject copy] ;
    }

    if ([keyName isEqualToString:@"imageAnimationFrame"]) {
        NSImage *theImage = _elementList[index][@"image"] ;
        if (theImage && [theImage isKindOfClass:[NSImage class]]) {
            for (NSBitmapImageRep *representation in [theImage representations]) {
                if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                    NSNumber *currentFrame = [representation valueForProperty:NSImageCurrentFrame] ;
                    if (currentFrame) {
                        foundObject = currentFrame ;
                        break ;
                    }
                }
            }
        }
    }

    if (foundObject && resolvePercentages) {
        CGFloat padding = [[self getElementValueFor:@"padding" atIndex:index] doubleValue] ;
        CGFloat paddedWidth = self.frame.size.width - padding * 2 ;
        CGFloat paddedHeight = self.frame.size.height - padding * 2 ;

        if ([keyName isEqualToString:@"radius"]) {
            if ([foundObject isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject) ;
                foundObject = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
        } else if ([keyName isEqualToString:@"center"]) {
            if ([foundObject[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"x"]) ;
                foundObject[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"y"]) ;
                foundObject[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
        } else if ([keyName isEqualToString:@"frame"]) {
            if ([foundObject[@"x"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"x"]) ;
                foundObject[@"x"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"y"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"y"]) ;
                foundObject[@"y"] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * paddedHeight)] ;
            }
            if ([foundObject[@"w"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"w"]) ;
                foundObject[@"w"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedWidth)] ;
            }
            if ([foundObject[@"h"] isKindOfClass:[NSString class]]) {
                NSNumber *percentage = convertPercentageStringToNumber(foundObject[@"h"]) ;
                foundObject[@"h"] = [NSNumber numberWithDouble:([percentage doubleValue] * paddedHeight)] ;
            }
        } else if ([keyName isEqualToString:@"coordinates"]) {
        // make sure we adjust a copy and not the actual items as defined; this is necessary because the copy above just does the top level element; this attribute is an array of objects unlike above attributes
            NSMutableArray *ourCopy = [[NSMutableArray alloc] init] ;
            [(NSMutableArray *)foundObject enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, __unused BOOL *stop) {
                NSMutableDictionary *targetItem = [[NSMutableDictionary alloc] init] ;
                for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                    if (subItem[field] && [subItem[field] isKindOfClass:[NSString class]]) {
                        NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                        CGFloat ourPadding = [field hasSuffix:@"x"] ? paddedWidth : paddedHeight ;
                        targetItem[field] = [NSNumber numberWithDouble:(padding + [percentage doubleValue] * ourPadding)] ;
                    } else {
                        targetItem[field] = subItem[field] ;
                    }
                }
                ourCopy[idx] = targetItem ;
            }] ;
            foundObject = ourCopy ;
        }
    }

    return foundObject ;
}

- (attributeValidity)setElementValueFor:(NSString *)keyName atIndex:(NSUInteger)index to:(id)keyValue withState:(lua_State *)L {
    if (index >= [_elementList count]) return attributeInvalid ;
    keyValue = [self massageKeyValue:keyValue forKey:keyName withState:L] ;
    __block attributeValidity validityStatus = isValueValidForAttribute(keyName, keyValue) ;

    switch (validityStatus) {
        case attributeValid: {
            if ([keyName isEqualToString:@"radius"]) {
                if ([keyValue isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"center"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"frame"]) {
                if ([keyValue[@"x"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"x"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field x of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"y"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"y"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field y of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"w"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"w"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field w of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
                if ([keyValue[@"h"] isKindOfClass:[NSString class]]) {
                    NSNumber *percentage = convertPercentageStringToNumber(keyValue[@"h"]) ;
                    if (!percentage) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field h of %@ for element %lu", USERDATA_TAG, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"coordinates"]) {
                [(NSMutableArray *)keyValue enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, NSUInteger idx, BOOL *stop) {
                    NSMutableSet *seenFields = [[NSMutableSet alloc] init] ;
                    for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                        if (subItem[field]) {
                            [seenFields addObject:field] ;
                            if ([subItem[field] isKindOfClass:[NSString class]]) {
                                NSNumber *percentage = convertPercentageStringToNumber(subItem[field]) ;
                                if (!percentage) {
                                    [LuaSkin logError:[NSString stringWithFormat:@"%s:invalid percentage string specified for field %@ at index %lu of %@ for element %lu", USERDATA_TAG, field, idx + 1, keyName, index + 1]];
                                    validityStatus = attributeInvalid ;
                                    *stop = YES ;
                                    break ;
                                }
                            }
                        }
                    }
                    BOOL goodForPoint = [seenFields containsObject:@"x"] && [seenFields containsObject:@"y"] ;
                    BOOL goodForCurve = goodForPoint && [seenFields containsObject:@"c1x"] && [seenFields containsObject:@"c1y"] &&
                                                        [seenFields containsObject:@"c2x"] && [seenFields containsObject:@"c2y"] ;
                    BOOL partialCurve = ([seenFields containsObject:@"c1x"] || [seenFields containsObject:@"c1y"] ||
                                        [seenFields containsObject:@"c2x"] || [seenFields containsObject:@"c2y"]) && !goodForCurve ;

                    if (!goodForPoint) {
                        [LuaSkin logError:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not specify a valid point or curve with control points", USERDATA_TAG, idx + 1, keyName, index + 1]];
                        validityStatus = attributeInvalid ;
                    } else if (goodForPoint && partialCurve) {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:index %lu of %@ for element %lu does not contain complete curve control points; treating as a singular point", USERDATA_TAG, idx + 1, keyName, index + 1]];
                    }
                }] ;
                if (validityStatus == attributeInvalid) break ;
            } else if ([keyName isEqualToString:@"canvas"]) {
                NSView *newView = (NSView *)keyValue ;
                NSView *oldView = (NSView *)_elementList[index][keyName] ;
                if (![newView isEqualTo:oldView]) {
                    if (![newView isDescendantOf:self] && ((!newView.window) || (newView.window && ![newView.window isVisible]))) {
                        if (oldView) {
                            [oldView removeFromSuperview] ;
                        }
                        [self addSubview:newView] ;
                    } else {
                        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:view for element %lu is already in use", USERDATA_TAG, index + 1]] ;
                        validityStatus = attributeInvalid ;
                        break ;
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [keyValue integerValue] % [maxFrames integerValue] ;
                                    while (newFrame < 0) newFrame = [maxFrames integerValue] + newFrame ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [keyValue boolValue] ;
                    HSGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[HSGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    HSGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
                BOOL shouldAnimate = [[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue] ;
                if (shouldAnimate) {
                    HSGifAnimator *animator = [[HSGifAnimator alloc] initWithImage:keyValue forCanvas:self] ;
                    if (animator) {
                        [_imageAnimations setObject:animator forKey:currentImage] ;
                        [animator startAnimating] ;
                    }
                }
            }

            if (![keyName isEqualToString:@"imageAnimationFrame"]) _elementList[index][keyName] = keyValue ;

            // add defaults, if not already present, for type (recurse into this method as needed)
            if ([keyName isEqualToString:@"type"]) {
                NSSet *defaultsForType = [languageDictionary keysOfEntriesPassingTest:^BOOL(NSString *typeName, NSDictionary *typeDefinition, __unused BOOL *stop){
                    return ![typeName isEqualToString:@"type"] && typeDefinition[@"requiredFor"] && [typeDefinition[@"requiredFor"] containsObject:keyValue] ;
                }] ;
                for (NSString *additionalKey in defaultsForType) {
                    if (!_elementList[index][additionalKey]) {
                        [self setElementValueFor:additionalKey atIndex:index to:[self getDefaultValueFor:additionalKey onlyIfSet:NO] withState:L] ;
                    }
                }
            }
        }   break ;
        case attributeNulling:
            if ([keyName isEqualToString:@"canvas"]) {
                NSView *oldView = (NSView *)_elementList[index][keyName] ;
                [oldView removeFromSuperview] ;
            } else if ([keyName isEqualToString:@"imageAnimationFrame"]) {
                if ([[self getElementValueFor:@"imageAnimates" atIndex:index] boolValue]) {
                    [LuaSkin logWarn:[NSString stringWithFormat:@"%s:%@ cannot be changed when element %lu is animating", USERDATA_TAG, keyName, index + 1]] ;
                    validityStatus = attributeInvalid ;
                    break ;
                } else {
                    NSImage *theImage = _elementList[index][@"image"] ;
                    if (theImage && [theImage isKindOfClass:[NSImage class]]) {
                        NSNumber *imageFrame = [self getDefaultValueFor:@"imageAnimationFrame" onlyIfSet:NO] ;
                        for (NSBitmapImageRep *representation in [theImage representations]) {
                            if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
                                NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
                                if (maxFrames) {
                                    lua_Integer newFrame = [imageFrame integerValue] % [maxFrames integerValue] ;
                                    [representation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
                                    break ;
                                }
                            }
                        }
                    }
                }
            } else if ([keyName isEqualToString:@"imageAnimates"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    BOOL shouldAnimate = [[self getDefaultValueFor:@"imageAnimates" onlyIfSet:NO] boolValue] ;
                    HSGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (shouldAnimate) {
                        if (!animator) {
                            animator = [[HSGifAnimator alloc] initWithImage:currentImage forCanvas:self] ;
                            if (animator) [_imageAnimations setObject:animator forKey:currentImage] ;
                        }
                        if (animator) [animator startAnimating] ;
                    } else {
                        if (animator) [animator stopAnimating] ;
                    }
                }
            } else if ([keyName isEqualToString:@"image"]) {
                NSImage *currentImage = _elementList[index][@"image"] ;
                if (currentImage && [currentImage isKindOfClass:[NSImage class]]) {
                    HSGifAnimator *animator = [_imageAnimations objectForKey:currentImage] ;
                    if (animator) {
                        [animator stopAnimating] ;
                        [_imageAnimations removeObjectForKey:currentImage] ;
                    }
                }
            }

            [(NSMutableDictionary *)_elementList[index] removeObjectForKey:keyName] ;
            break ;
        case attributeInvalid:
            break ;
        default:
            [LuaSkin logWarn:@"unexpected validity status returned; notify developers"] ;
            break ;
    }
    self.needsDisplay = YES ;
    return validityStatus ;
}

// see https://www.stairways.com/blog/2009-04-21-nsimage-from-nsview
- (NSImage *)imageWithSubviews {
    // Source: https://stackoverflow.com/questions/1733509/huge-memory-leak-in-nsbitmapimagerep/2189699
    @autoreleasepool {
        NSBitmapImageRep *bir = [self bitmapImageRepForCachingDisplayInRect:self.bounds];
        [bir setSize:self.bounds.size];
        [self cacheDisplayInRect:self.bounds toBitmapImageRep:bir];

        NSImage* image = [[NSImage alloc]initWithSize:self.bounds.size] ;
        [image addRepresentation:bir];

        return image;
    }
}

#pragma mark - View Animation Methods

- (void)fadeIn:(NSTimeInterval)fadeTime {
    CGFloat alphaSetting = self.alphaValue ;
    [self setAlphaValue:0.0];
    [self setHidden:NO];
    [NSAnimationContext beginGrouping];
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[self animator] setAlphaValue:alphaSetting];
    [NSAnimationContext endGrouping];
}

- (void)fadeOut:(NSTimeInterval)fadeTime andDelete:(BOOL)deleteView {
    CGFloat alphaSetting = self.alphaValue ;
    [NSAnimationContext beginGrouping];
      __weak HSCanvasView *bself = self; // in ARC, __block would increase retain count
      [[NSAnimationContext currentContext] setDuration:fadeTime];
      [[NSAnimationContext currentContext] setCompletionHandler:^{
          // unlikely that bself will go to nil after this starts, but this keeps the warnings down from [-Warc-repeated-use-of-weak]
          HSCanvasView *mySelf = bself ;
          if (mySelf) {
              if (deleteView) {
                  [mySelf removeFromSuperview] ;
              } else {
                  [mySelf setHidden:YES];
                  [mySelf setAlphaValue:alphaSetting];
              }
          }
      }];
      [[self animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
}

#pragma mark - NSDraggingDestination protocol methods

- (BOOL)draggingCallback:(NSString *)message with:(id<NSDraggingInfo>)sender {
    BOOL isAllGood = NO ;
    if (_draggingCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        lua_State *L = skin.L ;
        _lua_stackguard_entry(L);
        int argCount = 2 ;
        [skin pushLuaRef:refTable ref:_draggingCallbackRef] ;
        [skin pushNSObject:self] ;
        [skin pushNSObject:message] ;
        if (sender) {
            lua_newtable(L) ;
            NSPasteboard *pasteboard = [sender draggingPasteboard] ;
            if (pasteboard) {
                [skin pushNSObject:pasteboard.name] ; lua_setfield(L, -2, "pasteboard") ;
            }
            lua_pushinteger(L, [sender draggingSequenceNumber]) ; lua_setfield(L, -2, "sequence") ;
            [skin pushNSPoint:[sender draggingLocation]] ; lua_setfield(L, -2, "mouse") ;
            NSDragOperation operation = [sender draggingSourceOperationMask] ;
            lua_newtable(L) ;
            if (operation == NSDragOperationNone) {
                lua_pushstring(L, "none") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
            } else {
                if ((operation & NSDragOperationCopy) == NSDragOperationCopy) {
                    lua_pushstring(L, "copy") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationLink) == NSDragOperationLink) {
                    lua_pushstring(L, "link") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationGeneric) == NSDragOperationGeneric) {
                    lua_pushstring(L, "generic") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationPrivate) == NSDragOperationPrivate) {
                    lua_pushstring(L, "private") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationMove) == NSDragOperationMove) {
                    lua_pushstring(L, "move") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
                if ((operation & NSDragOperationDelete) == NSDragOperationDelete) {
                    lua_pushstring(L, "delete") ; lua_rawseti(L, -2, luaL_len(L, -2) + 1)  ;
                }
            }
            lua_setfield(L, -2, "operation") ;
            argCount += 1 ;
        }
        if ([skin protectedCallAndTraceback:argCount nresults:1]) {
            isAllGood = lua_isnoneornil(L, -1) ? YES : (BOOL)lua_toboolean(skin.L, -1) ;
        } else {
            [skin logError:[NSString stringWithFormat:@"%s:draggingCallback error: %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
            // No need to lua_pop() the error because nresults is 1, so the call below gets it whether it's a successful result or an error message
        }
        lua_pop(L, 1) ;
        _lua_stackguard_exit(L);
    }
    return isAllGood ;
}

- (BOOL)wantsPeriodicDraggingUpdates {
    return NO ;
}

- (BOOL)prepareForDragOperation:(__unused id<NSDraggingInfo>)sender {
    return YES ;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"enter" with:sender] ? NSDragOperationGeneric : NSDragOperationNone ;
}

- (void)draggingExited:(id<NSDraggingInfo>)sender {
    [self draggingCallback:@"exit" with:sender] ;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    return [self draggingCallback:@"receive" with:sender] ;
}

// - (NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender ;
// - (void)concludeDragOperation:(id<NSDraggingInfo>)sender ;
// - (void)draggingEnded:(id<NSDraggingInfo>)sender ;
// - (void)updateDraggingItemsForDrag:(id<NSDraggingInfo>)sender

@end

#pragma mark - Module Functions

/// hs.canvas.useCustomAccessibilitySubrole([state]) -> boolean
/// Function
/// Get or set whether or not canvas objects use a custom accessibility subrole for the contaning system window.
///
/// Parameters:
///  * `state` - an optional boolean, default true, specifying whether or not canvas containers should use a custom accessibility subrole.
///
/// Returns:
///  * the current, possibly changed, value as a boolean
///
/// Notes:
///  * Under some conditions, it has been observed that Hammerspoon's `hs.window.filter` module will misidentify Canvas and Drawing objects as windows of the Hammerspoon application that it should consider when evaluating its filters. To eliminate this, `hs.canvas` objects (and previously `hs.drawing` objects, which are now deprecated and pass through to `hs.canvas`) were given a nonstandard accessibilty subrole to prevent them from being included. This has caused some issues with third party tools, like Yabai, which also use the accessibility subroles for determining what actions it may take with Hammerspoon windows.
///
///  * By passing `false` to this function, all canvas objects will revert to specifying the standard subrole for the containing windows by default and should work as expected with third party tools. Note that this may cause issues or slowdowns if you are also using `hs.window.filter`; a more permanent solution is being considered.
///
///  * If you need to control the subrole of canvas objects more specifically, or only for some canvas objects, see [hs.canvas:_accessibilitySubrole](#_accessibilitySubrole).
static int canvas_useCustomAccessibilitySubrole(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 1) {
        defaultCustomSubRole = lua_toboolean(L, 1) ;
    }
    lua_pushboolean(L, defaultCustomSubRole) ;
    return 1 ;
}

/// hs.canvas.new(rect) -> canvasObject
/// Constructor
/// Create a new canvas object at the specified coordinates
///
/// Parameters:
///  * `rect` - A rect-table containing the co-ordinates and size for the canvas object
///
/// Returns:
///  * a new, empty, canvas object, or nil if the canvas cannot be created with the specified coordinates
///
/// Notes:
///  * The size of the canvas defines the visible area of the canvas -- any portion of a canvas element which extends past the canvas's edges will be clipped.
///  * a rect-table is a table with key-value pairs specifying the top-left coordinate on the screen for the canvas (keys `x`  and `y`) and the size (keys `h` and `w`) of the canvas. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;

    HSCanvasWindow *canvasWindow = [[HSCanvasWindow alloc] initWithContentRect:[skin tableToRectAtIndex:1]
                                                                     styleMask:NSWindowStyleMaskBorderless
                                                                         backing:NSBackingStoreBuffered
                                                                           defer:YES] ;
    if (canvasWindow) {
        HSCanvasView *canvasView = [[HSCanvasView alloc] initWithFrame:canvasWindow.contentView.bounds];
        canvasView.wrapperWindow = canvasWindow ;
        canvasWindow.contentView = canvasView ;

        [skin pushNSObject:canvasView] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.canvas.elementSpec() -> table
/// Function
/// Returns the list of attributes and their specifications that are recognized for canvas elements by this module.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the attributes and specifications defined for this module.
///
/// Notes:
///  * This is primarily for debugging purposes and may be removed in the future.
static int dumpLanguageDictionary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:languageDictionary withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

/// hs.canvas.defaultTextStyle() -> `hs.styledtext` attributes table
/// Function
/// Returns a table containing the default font, size, color, and paragraphStyle used by `hs.canvas` for text drawing objects.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the default style attributes `hs.canvas` uses for text drawing objects in the `hs.styledtext` attributes table format.
///
/// Notes:
///  * This method is intended to be used in conjunction with `hs.styledtext` to create styledtext objects that are based on, or a slight variation of, the defaults used by `hs.canvas`.
static int default_textAttributes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    lua_newtable(L) ;
    NSString *fontName = languageDictionary[@"textFont"][@"default"] ;
    if (fontName) {
        [skin pushNSObject:[NSFont fontWithName:fontName
                                           size:[languageDictionary[@"textSize"][@"default"] doubleValue]]] ;
        lua_setfield(L, -2, "font") ;
        [skin pushNSObject:languageDictionary[@"textColor"][@"default"]] ;
        lua_setfield(L, -2, "color") ;
        [skin pushNSObject:[NSParagraphStyle defaultParagraphStyle]] ;
        lua_setfield(L, -2, "paragraphStyle") ;
    } else {
        return luaL_error(L, "%s:unable to get default font name from element language dictionary", USERDATA_TAG) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.canvas:draggingCallback(fn) -> canvasObject
/// Method
/// Sets or remove a callback for accepting dragging and dropping items onto the canvas.
///
/// Parameters:
///  * `fn`   - A function, can be nil, that will be called when an item is dragged onto the canvas.  An explicit nil, the default, disables drag-and-drop for this canvas.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * The callback function should expect 3 arguments and optionally return 1: the canvas object itself, a message specifying the type of dragging event, and a table containing details about the item(s) being dragged.  The key-value pairs of the details table will be the following:
///    * `pasteboard` - the name of the pasteboard that contains the items being dragged
///    * `sequence`   - an integer that uniquely identifies the dragging session.
///    * `mouse`      - a point table containing the location of the mouse pointer within the canvas corresponding to when the callback occurred.
///    * `operation`  - a table containing string descriptions of the type of dragging the source application supports. Potentially useful for determining if your callback function should accept the dragged item or not.
///
/// * The possible messages the callback function may receive are as follows:
///    * "enter"   - the user has dragged an item into the canvas.  When your callback receives this message, you can optionally return false to indicate that you do not wish to accept the item being dragged.
///    * "exit"    - the user has moved the item out of the canvas; if the previous "enter" callback returned false, this message will also occur when the user finally releases the items being dragged.
///    * "receive" - indicates that the user has released the dragged object while it is still within the canvas frame.  When your callback receives this message, you can optionally return false to indicate to the sending application that you do not want to accept the dragged item -- this may affect the animations provided by the sending application.
///
///  * You can use the sequence number in the details table to match up an "enter" with an "exit" or "receive" message.
///
///  * You should capture the details you require from the drag-and-drop operation during the callback for "receive" by using the pasteboard field of the details table and the `hs.pasteboard` module.  Because of the nature of "promised items", it is not guaranteed that the items will still be on the pasteboard after your callback completes handling this message.
///
///  * A canvas object can only accept drag-and-drop items when its window level is at [hs.canvas.windowLevels.dragging](#windowLevels) or lower.
///  * a canvas object can only accept drag-and-drop items when it accepts mouse events.  You must define a [hs.canvas:mouseCallback](#mouseCallback) function, even if it is only a placeholder, e.g. `hs.canvas:mouseCallback(function() end)`
static int canvas_draggingCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    // We're either removing callback(s), or setting new one(s). Either way, remove existing.
    canvasView.draggingCallbackRef = [skin luaUnref:refTable ref:canvasView.draggingCallbackRef];
    [canvasView unregisterDraggedTypes] ;
    if ([skin luaTypeAtIndex:2] == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        canvasView.draggingCallbackRef = [skin luaRef:refTable] ;
        [canvasView registerForDraggedTypes:@[ (__bridge NSString *)kUTTypeItem ]] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.canvas:_accessibilitySubrole([subrole]) -> canvasObject | current value
/// Method
/// Get or set the accessibility subrole returned by `hs.canvas` objects.
///
/// Parameters:
///  * `subrole` - an optional string or explicit nil wihch specifies what accessibility subrole value should be returned when canvas objects are queried through the macOS accessibility framework. See Notes for a discussion of how this value is interpreted. Defaults to `nil`.
///
/// Returns:
///  * If an argument is specified, returns the canvasObject; otherwise returns the current value.
///
/// Notes:
///  * Most people will probably not need to use this method; See [hs.canvas.useCustomAccessibilitySubrole](#useCustomAccessibilitySubrole) for a discussion as to why this method may be of use when Hammerspoon is being controlled through the accessibility framework by other applications.
///
///  * If a non empty string is specified as the argument to this method, the string will be returned whenever the canvas object's containing window is queried for its accessibility subrole.
///  * The other possible values depend upon the value registerd with [hs.canvas.useCustomAccessibilitySubrole](#useCustomAccessibilitySubrole):
///    * If `useCustomAccessibilitySubrole` is set to true (the default):
///      * If an explicit `nil` (the default) is specified fror this method, the string returned when the canvas object's accessibility is queried will be the default macOS subrole for the canvas's window with the string ".Hammerspoon` appended to it.
///      * If the empty string is specified (e.g. `""`), then the default macOS subrole for the canvas's window will be returned.
///    * If `useCustomAccessibilitySubrole` is set to false:
///      * If an explicit `nil` (the default) is specified fror this method, then the default macOS subrole for the canvas's window will be returned.
///      * If the empty string is specified (e.g. `""`), the string returned when the canvas object's accessibility is queried will be the default macOS subrole for the canvas's window with the string ".Hammerspoon` appended to it.
static int canvas_accessibilitySubrole(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

    if (lua_gettop(L) == 1) {
      [skin pushNSObject:canvasWindow.subroleOverride] ;
    } else {
        canvasWindow.subroleOverride = lua_isstring(L, 2) ? [skin toNSObjectAtIndex:2] : nil ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.canvas:minimumTextSize([index], text) -> table
/// Method
/// Returns a table specifying the size of the rectangle which can fully render the text with the specified style so that is will be completely visible.
///
/// Parameters:
///  * `index` - an optional index specifying the element in the canvas which contains the text attributes which should be used when determining the size of the text. If not provided, the canvas defaults will be used instead. Ignored if `text` is an hs.styledtext object.
///  * `text`  - a string or hs.styledtext object specifying the text.
///
/// Returns:
///  * a size table specifying the height and width of a rectangle which could fully contain the text when displayed in the canvas
///
/// Notes:
///  * Multi-line text (separated by a newline or return) is supported.  The height will be for the multiple lines and the width returned will be for the longest line.
static int canvas_getTextElementSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK | LS_TVARARG] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    int        textIndex    = 2 ;
    NSUInteger elementIndex = NSNotFound ;
    if (lua_gettop(L) == 3) {
        if (lua_type(L, 3) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TUSERDATA, "hs.styledtext",
                            LS_TBREAK] ;
        }
        elementIndex = (NSUInteger)lua_tointeger(L, 2) - 1 ;
        if ((NSInteger)elementIndex < 0 || elementIndex >= [canvasView.elementList count]) {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", elementIndex + 1] UTF8String]) ;
        }
        textIndex = 3 ;
    } else {
        if (lua_type(L, 2) == LUA_TSTRING) {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TUSERDATA, "hs.styledtext",
                            LS_TBREAK] ;
        }
    }
    NSSize theSize = NSZeroSize ;
    NSString *theText = [skin toNSObjectAtIndex:textIndex] ;

    if (lua_type(L, textIndex) == LUA_TSTRING) {
        NSString *myFont = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textFont" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textFont" atIndex:elementIndex onlyIfSet:NO] ;
        NSNumber *mySize = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textSize" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textSize" atIndex:elementIndex onlyIfSet:NO] ;
        NSMutableParagraphStyle *theParagraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        NSString *alignment = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textAlignment" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textAlignment" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.alignment = [TEXTALIGNMENT_TYPES[alignment] unsignedIntValue] ;
        NSString *wrap = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textLineBreak" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textLineBreak" atIndex:elementIndex onlyIfSet:NO] ;
        theParagraphStyle.lineBreakMode = [TEXTWRAP_TYPES[wrap] unsignedIntValue] ;
        NSColor *color = (elementIndex == NSNotFound) ?
            [canvasView getDefaultValueFor:@"textColor" onlyIfSet:NO] :
            [canvasView getElementValueFor:@"textColor" atIndex:elementIndex onlyIfSet:NO] ;
        NSDictionary *attributes = @{
            NSForegroundColorAttributeName : color,
            NSFontAttributeName            : [NSFont fontWithName:myFont size:[mySize doubleValue]],
            NSParagraphStyleAttributeName  : theParagraphStyle,
        } ;
        theSize = [theText sizeWithAttributes:attributes] ;
    } else {
//       NSAttributedString *theText = [skin luaObjectAtIndex:textIndex toClass:"NSAttributedString"] ;
      theSize = [(NSAttributedString *)theText size] ;
    }
    [skin pushNSSize:theSize] ;
    return 1 ;
}

/// hs.canvas:transformation([matrix]) -> canvasObject | current value
/// Method
/// Get or set the matrix transformation which is applied to every element in the canvas before being individually processed and added to the canvas.
///
/// Parameters:
///  * `matrix` - an optional table specifying the matrix table, as defined by the [hs.canvas.matrix](MATRIX.md) module, to be applied to every element of the canvas, or an explicit `nil` to reset the transformation to the identity matrix.
///
/// Returns:
///  * if an argument is provided, returns the canvasObject, otherwise returns the current value
///
/// Notes:
///  * An example use for this method would be to change the canvas's origin point { x = 0, y = 0 } from the lower left corner of the canvas to somewhere else, like the middle of the canvas.
static int canvas_canvasTransformation(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:canvasView.canvasTransform] ;
    } else {
        NSAffineTransform *transform = [NSAffineTransform transform] ;
        if (lua_type(L, 2) == LUA_TTABLE) transform = [skin luaObjectAtIndex:2 toClass:"NSAffineTransform"] ;
        canvasView.canvasTransform = transform ;
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.canvas:show([fadeInTime]) -> canvasObject
/// Method
/// Displays the canvas object
///
/// Parameters:
///  * `fadeInTime` - An optional number of seconds over which to fade in the canvas object. Defaults to zero.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * if the canvas is in use as an element in another canvas, this method will result in an error.
static int canvas_show(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

    if (lua_gettop(L) == 1) {
        if (parentIsWindow(canvasView)) {
            [canvasWindow makeKeyAndOrderFront:nil];
        } else {
            canvasView.hidden = NO ;
        }
    } else {
        if (parentIsWindow(canvasView)) {
            [canvasWindow fadeIn:lua_tonumber(L, 2)];
        } else {
            [canvasView fadeIn:lua_tonumber(L, 2)];
        }
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.canvas:hide([fadeOutTime]) -> canvasObject
/// Method
/// Hides the canvas object
///
/// Parameters:
///  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
///
/// Returns:
///  * The canvas object
static int canvas_hide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

    if (lua_gettop(L) == 1) {
        if (parentIsWindow(canvasView)) {
            [canvasWindow orderOut:nil];
        } else {
            canvasView.hidden = YES ;
        }
    } else {
        if (parentIsWindow(canvasView)) {
            [canvasWindow fadeOut:lua_tonumber(L, 2) andDelete:NO withState:L];
        } else {
            [canvasView fadeOut:lua_tonumber(L, 2) andDelete:NO];
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.canvas:mouseCallback(mouseCallbackFn) -> canvasObject
/// Method
/// Sets a callback for mouse events with respect to the canvas
///
/// Parameters:
///  * `mouseCallbackFn`   - A function, can be nil, that will be called when a mouse event occurs within the canvas, and an element beneath the mouse's current position has one of the `trackMouse...` attributes set to true.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * The callback function should expect 5 arguments: the canvas object itself, a message specifying the type of mouse event, the canvas element `id` (or index position in the canvas if the `id` attribute is not set for the element), the x position of the mouse when the event was triggered within the rendered portion of the canvas element, and the y position of the mouse when the event was triggered within the rendered portion of the canvas element.
///  * See also [hs.canvas:canvasMouseEvents](#canvasMouseEvents) for tracking mouse events in regions of the canvas not covered by an element with mouse tracking enabled.
///
///  * The following mouse attributes may be set to true for a canvas element and will invoke the callback with the specified message:
///    * `trackMouseDown`      - indicates that a callback should be invoked when a mouse button is clicked down on the canvas element.  The message will be "mouseDown".
///    * `trackMouseUp`        - indicates that a callback should be invoked when a mouse button has been released over the canvas element.  The message will be "mouseUp".
///    * `trackMouseEnterExit` - indicates that a callback should be invoked when the mouse pointer enters or exits the  canvas element.  The message will be "mouseEnter" or "mouseExit".
///    * `trackMouseMove`      - indicates that a callback should be invoked when the mouse pointer moves within the canvas element.  The message will be "mouseMove".
///
///  * The callback mechanism uses reverse z-indexing to determine which element will receive the callback -- the topmost element of the canvas which has enabled callbacks for the specified message will be invoked.
///
///  * No distinction is made between the left, right, or other mouse buttons. If you need to determine which specific button was pressed, use `hs.eventtap.checkMouseButtons()` within your callback to check.
///
///  * The hit point detection occurs by comparing the mouse pointer location to the rendered content of each individual canvas object... if an object which obscures a lower object does not have mouse tracking enabled, the lower object will still receive the event if it does have tracking enabled.
///
///  * Clipping regions which remove content from the visible area of a rendered object are ignored for the purposes of element hit-detection.
static int canvas_mouseCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TFUNCTION | LS_TNIL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = canvasView.wrapperWindow ;

    // We're either removing callback(s), or setting new one(s). Either way, remove existing.
    canvasView.mouseCallbackRef = [skin luaUnref:refTable ref:canvasView.mouseCallbackRef];
    canvasView.previousTrackedIndex = NSNotFound ;
    canvasWindow.ignoresMouseEvents = YES ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        canvasView.mouseCallbackRef = [skin luaRef:refTable] ;
        canvasWindow.ignoresMouseEvents = NO ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.canvas:clickActivating([flag]) -> canvasObject | currentValue
/// Method
/// Get or set whether or not clicking on a canvas with a click callback defined should bring all of Hammerspoon's open windows to the front.
///
/// Parameters:
///  * `flag` - an optional boolean indicating whether or not clicking on a canvas with a click callback function defined should activate Hammerspoon and bring its windows forward. Defaults to true.
///
/// Returns:
///  * If an argument is provided, returns the canvas object; otherwise returns the current setting.
///
/// Notes:
///  * Setting this to false changes a canvas object's AXsubrole value and may affect the results of filters used with `hs.window.filter`, depending upon how they are defined.
static int canvas_clickActivating(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = canvasView.wrapperWindow ;

    if (lua_type(L, 2) != LUA_TNONE) {
        if (lua_toboolean(L, 2)) {
            canvasWindow.styleMask &= (unsigned long)~NSWindowStyleMaskNonactivatingPanel ;
        } else {
            canvasWindow.styleMask |= NSWindowStyleMaskNonactivatingPanel ;
        }
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, ((canvasWindow.styleMask & NSWindowStyleMaskNonactivatingPanel) != NSWindowStyleMaskNonactivatingPanel)) ;
    }

    return 1;
}

/// hs.canvas:canvasMouseEvents([down], [up], [enterExit], [move]) -> canvasObject | current values
/// Method
/// Get or set whether or not regions of the canvas which are not otherwise covered by an element with mouse tracking enabled should generate a callback for mouse events.
///
/// Parameters:
///  * `down`      - an optional boolean, or nil placeholder, specifying whether or not the mouse button being pushed down should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `up`        - an optional boolean, or nil placeholder, specifying whether or not the mouse button being released should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `enterExit` - an optional boolean, or nil placeholder, specifying whether or not the mouse pointer entering or exiting the canvas bounds should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///  * `move`      - an optional boolean, or nil placeholder, specifying whether or not the mouse pointer moving within the canvas bounds should generate a callback for the canvas areas not otherwise covered by an element with mouse tracking enabled.
///
/// Returns:
///  * If any arguments are provided, returns the canvas Object, otherwise returns the current values as four separate boolean values (i.e. not in a table).
///
/// Notes:
///  * Each value that you wish to set must be provided in the order given above, but you may specify a position as `nil` to indicate that whatever it's current state, no change should be applied.  For example, to activate a callback for entering and exiting the canvas without changing the current callback status for up or down button clicks, you could use: `hs.canvas:canvasMouseTracking(nil, nil, true)`.
///
///  * Use [hs.canvas:mouseCallback](#mouseCallback) to set the callback function.  The identifier field in the callback's argument list will be "_canvas_", but otherwise identical to those specified in [hs.canvas:mouseCallback](#mouseCallback).
static int canvas_canvasMouseEvents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TNIL | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    if (lua_gettop(L) == 1) {
        lua_pushboolean(L, canvasView.canvasMouseDown) ;
        lua_pushboolean(L, canvasView.canvasMouseUp) ;
        lua_pushboolean(L, canvasView.canvasMouseEnterExit) ;
        lua_pushboolean(L, canvasView.canvasMouseMove) ;
        return 4 ;
    } else {
        if (lua_type(L, 2) == LUA_TBOOLEAN) {
            canvasView.canvasMouseDown = (BOOL)lua_toboolean(L, 2) ;
        }
        if (lua_type(L, 3) == LUA_TBOOLEAN) {
            canvasView.canvasMouseUp = (BOOL)lua_toboolean(L, 3) ;
        }
        if (lua_type(L, 4) == LUA_TBOOLEAN) {
            canvasView.canvasMouseEnterExit = (BOOL)lua_toboolean(L, 4) ;
        }
        if (lua_type(L, 5) == LUA_TBOOLEAN) {
            canvasView.canvasMouseMove = (BOOL)lua_toboolean(L, 5) ;
        }

        lua_pushvalue(L, 1) ;
        return 1;
    }
}

/// hs.canvas:topLeft([point]) -> canvasObject | currentValue
/// Method
/// Get or set the top-left coordinate of the canvas object
///
/// Parameters:
///  * `point` - An optional point-table specifying the new coordinate the top-left of the canvas object should be moved to
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * a point-table is a table with key-value pairs specifying the new top-left coordinate on the screen of the canvas (keys `x`  and `y`). The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
static int canvas_topLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if (parentIsWindow(canvasView)) {
        HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;
        NSRect oldFrame = RectWithFlippedYCoordinate(canvasWindow.frame);

        if (lua_gettop(L) == 1) {
            [skin pushNSPoint:oldFrame.origin] ;
        } else {
            NSPoint newCoord = [skin tableToPointAtIndex:2] ;
            NSRect  newFrame = RectWithFlippedYCoordinate(NSMakeRect(newCoord.x, newCoord.y, oldFrame.size.width, oldFrame.size.height)) ;
            [canvasWindow setFrame:newFrame display:YES animate:NO];
            lua_pushvalue(L, 1);
        }
    } else {
        return luaL_argerror(L, 1, "method unavailable for canvas as a subview") ;
    }
    return 1;
}

/// hs.canvas:imageFromCanvas() -> hs.image object
/// Method
/// Returns an image of the canvas contents as an `hs.image` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an `hs.image` object
///
/// Notes:
///  * The canvas does not have to be visible in order for an image to be generated from it.
static int canvas_canvasAsImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSImage *image = [canvasView imageWithSubviews] ;
    [skin pushNSObject:image] ;
    return 1;
}



/// hs.canvas:size([size]) -> canvasObject | currentValue
/// Method
/// Get or set the size of a canvas object
///
/// Parameters:
///  * `size` - An optional size-table specifying the width and height the canvas object should be resized to
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * a size-table is a table with key-value pairs specifying the size (keys `h` and `w`) the canvas should be resized to. The table may be crafted by any method which includes these keys, including the use of an `hs.geometry` object.
///
///  * elements in the canvas that have the `absolutePosition` attribute set to false will be moved so that their relative position within the canvas remains the same with respect to the new size.
///  * elements in the canvas that have the `absoluteSize` attribute set to false will be resized so that their relative size with respect to the canvas remains the same with respect to the new size.
static int canvas_size(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if (parentIsWindow(canvasView)) {
        HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

        NSRect oldFrame = canvasWindow.frame;

        if (lua_gettop(L) == 1) {
            [skin pushNSSize:oldFrame.size] ;
        } else {
            NSSize newSize  = [skin tableToSizeAtIndex:2] ;
            NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - newSize.height, newSize.width, newSize.height);

            CGFloat xFactor = newFrame.size.width / oldFrame.size.width ;
            CGFloat yFactor = newFrame.size.height / oldFrame.size.height ;

            for (NSUInteger i = 0 ; i < [canvasView.elementList count] ; i++) {
                NSNumber *absPos = [canvasView getElementValueFor:@"absolutePosition" atIndex:i] ;
                NSNumber *absSiz = [canvasView getElementValueFor:@"absoluteSize" atIndex:i] ;
                if (absPos && absSiz) {
                    BOOL absolutePosition = absPos ? [absPos boolValue] : YES ;
                    BOOL absoluteSize     = absSiz ? [absSiz boolValue] : YES ;
                    NSMutableDictionary *attributeDefinition = canvasView.elementList[i] ;
                    if (!absolutePosition) {
                        [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                            if ([keyName isEqualToString:@"center"] || [keyName isEqualToString:@"frame"]) {
                                if ([keyValue[@"x"] isKindOfClass:[NSNumber class]]) {
                                    keyValue[@"x"] = [NSNumber numberWithDouble:([keyValue[@"x"] doubleValue] * xFactor)] ;
                                }
                                if ([keyValue[@"y"] isKindOfClass:[NSNumber class]]) {
                                    keyValue[@"y"] = [NSNumber numberWithDouble:([keyValue[@"y"] doubleValue] * yFactor)] ;
                                }
                            } else if ([keyName isEqualTo:@"coordinates"]) {
                                [(NSMutableArray *)keyValue enumerateObjectsUsingBlock:^(NSMutableDictionary *subItem, __unused NSUInteger idx, __unused BOOL *stop2) {
                                    for (NSString *field in @[ @"x", @"y", @"c1x", @"c1y", @"c2x", @"c2y" ]) {
                                        if (subItem[field] && [subItem[field] isKindOfClass:[NSNumber class]]) {
                                            CGFloat ourFactor = [field hasSuffix:@"x"] ? xFactor : yFactor ;
                                            subItem[field] = [NSNumber numberWithDouble:([subItem[field] doubleValue] * ourFactor)] ;
                                        }
                                    }
                                }] ;

                            }
                        }] ;
                    }
                    if (!absoluteSize) {
                        [attributeDefinition enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                            if ([keyName isEqualToString:@"frame"]) {
                                if ([keyValue[@"h"] isKindOfClass:[NSNumber class]]) {
                                    keyValue[@"h"] = [NSNumber numberWithDouble:([keyValue[@"h"] doubleValue] * yFactor)] ;
                                }
                                if ([keyValue[@"w"] isKindOfClass:[NSNumber class]]) {
                                    keyValue[@"w"] = [NSNumber numberWithDouble:([keyValue[@"w"] doubleValue] * xFactor)] ;
                                }
                            } else if ([keyName isEqualToString:@"radius"]) {
                                if ([keyValue isKindOfClass:[NSNumber class]]) {
                                    attributeDefinition[keyName] = [NSNumber numberWithDouble:([keyValue doubleValue] * xFactor)] ;
                                }
                            }
                        }] ;
                    }
                } else {
                    [skin logError:[NSString stringWithFormat:@"%s:unable to get absolute positioning info for index position %lu", USERDATA_TAG, i + 1]] ;
                }
            }
            [canvasWindow setFrame:newFrame display:YES animate:NO];
            lua_pushvalue(L, 1);
        }
    } else {
        return luaL_argerror(L, 1, "method unavailable for canvas as a subview") ;
    }
    return 1;
}

/// hs.canvas:alpha([alpha]) -> canvasObject | currentValue
/// Method
/// Get or set the alpha level of the window containing the canvasObject.
///
/// Parameters:
///  * `alpha` - an optional number specifying the new alpha level (0.0 - 1.0, inclusive) for the canvasObject
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
static int canvas_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

    if (lua_gettop(L) == 1) {
        if (parentIsWindow(canvasView)) {
            lua_pushnumber(L, canvasWindow.alphaValue) ;
        } else {
            lua_pushnumber(L, canvasView.alphaValue) ;
        }
    } else {
        CGFloat newLevel = luaL_checknumber(L, 2);
        if (parentIsWindow(canvasView)) {
            canvasWindow.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        } else {
            canvasView.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
        }
        lua_pushvalue(L, 1);
    }

    return 1 ;
}

/// hs.canvas:orderAbove([canvas2]) -> canvasObject
/// Method
/// Moves canvas object above canvas2, or all canvas objects in the same presentation level, if canvas2 is not given.
///
/// Parameters:
///  * `canvas2` -An optional canvas object to place the canvas object above.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * If the canvas object and canvas2 are not at the same presentation level, this method will will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs.canvas.level](#level).
static int canvas_orderAbove(lua_State *L) {
    return canvas_orderHelper(L, NSWindowAbove) ;
}

/// hs.canvas:orderBelow([canvas2]) -> canvasObject
/// Method
/// Moves canvas object below canvas2, or all canvas objects in the same presentation level, if canvas2 is not given.
///
/// Parameters:
///  * `canvas2` -An optional canvas object to place the canvas object below.
///
/// Returns:
///  * The canvas object
///
/// Notes:
///  * If the canvas object and canvas2 are not at the same presentation level, this method will will move the canvas object as close to the desired relationship as possible without changing the canvas object's presentation level. See [hs.canvas.level](#level).
static int canvas_orderBelow(lua_State *L) {
    return canvas_orderHelper(L, NSWindowBelow) ;
}

/// hs.canvas:level([level]) -> canvasObject | currentValue
/// Method
/// Sets the window level more precisely than sendToBack and bringToFront.
///
/// Parameters:
///  * `level` - an optional level, specified as a number or as a string, specifying the new window level for the canvasObject. If it is a string, it must match one of the keys in [hs.canvas.windowLevels](#windowLevels).
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
static int canvas_level(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TSTRING | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if (parentIsWindow(canvasView)) {
        HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

        if (lua_gettop(L) == 1) {
            lua_pushinteger(L, [canvasWindow level]) ;
        } else {
            lua_Integer targetLevel ;
            if (lua_type(L, 2) == LUA_TNUMBER) {
                [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TNUMBER | LS_TINTEGER,
                                LS_TBREAK] ;
                targetLevel = lua_tointeger(L, 2) ;
            } else {
                cg_windowLevels(L) ;
                if (lua_getfield(L, -1, [[skin toNSObjectAtIndex:2] UTF8String]) == LUA_TNUMBER) {
                    targetLevel = lua_tointeger(L, -1) ;
                    lua_pop(L, 2) ; // value and cg_windowLevels() table
                } else {
                    lua_pop(L, 2) ; // wrong value and cg_windowLevels() table
                    return luaL_error(L, [[NSString stringWithFormat:@"unrecognized window level: %@", [skin toNSObjectAtIndex:2]] UTF8String]) ;
                }
            }

            targetLevel = (targetLevel < CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ? CGWindowLevelForKey(kCGMinimumWindowLevelKey) : ((targetLevel > CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ? CGWindowLevelForKey(kCGMaximumWindowLevelKey) : targetLevel) ;
            [canvasWindow setLevel:targetLevel] ;
            lua_pushvalue(L, 1) ;
        }
    } else {
        return luaL_argerror(L, 1, "method unavailable for canvas as a subview") ;
    }

    return 1 ;
}

/// hs.canvas:wantsLayer([flag]) -> canvasObject | currentValue
/// Method
/// Get or set whether or not the canvas object should be rendered by the view or by Core Animation.
///
/// Parameters:
///  * `flag` - optional boolean (default false) which indicates whether the canvas object should be rendered by the containing view (false) or by Core Animation (true).
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * This method can help smooth the display of small text objects on non-Retina monitors.
static int canvas_wantsLayer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    if (lua_type(L, 2) != LUA_TNONE) {
        [canvasView setWantsLayer:(BOOL)lua_toboolean(L, 2)];
        canvasView.needsDisplay = YES ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, (BOOL)[canvasView wantsLayer]) ;
    }

    return 1;
}

static int canvas_behavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if (parentIsWindow(canvasView)) {
        HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;

        if (lua_gettop(L) == 1) {
            lua_pushinteger(L, [canvasWindow collectionBehavior]) ;
        } else {
            [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                            LS_TNUMBER | LS_TINTEGER,
                            LS_TBREAK] ;

            NSInteger newLevel = lua_tointeger(L, 2);
            @try {
                [canvasWindow setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
            }
            @catch ( NSException *theException ) {
                return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
            }

            lua_pushvalue(L, 1);
        }
    } else {
        return luaL_argerror(L, 1, "method unavailable for canvas as a subview") ;
    }

    return 1 ;
}

/// hs.canvas:delete([fadeOutTime]) -> none
/// Method
/// Destroys the canvas object, optionally fading it out first (if currently visible).
///
/// Parameters:
///  * `fadeOutTime` - An optional number of seconds over which to fade out the canvas object. Defaults to zero.
///
/// Returns:
///  * None
///
/// Notes:
///  * This method is automatically called during garbage collection, notably during a Hammerspoon termination or reload, with a fade time of 0.
static int canvas_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = canvasView.wrapperWindow ;
    if ((lua_gettop(L) == 1) || (![canvasWindow isVisible])) {
        lua_pushcfunction(L, userdata_gc) ;
        lua_pushvalue(L, 1) ;
        // FIXME: Can we convert this lua_pcall() to a LuaSkin protectedCallAndError?
        if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"%s:error invoking _gc for delete method:%s", USERDATA_TAG, lua_tostring(L, -1)]] ;
            lua_pop(L, 1) ;
            [canvasWindow close] ; // the least we can do is close the canvas if an error occurs with __gc
        }
    } else {
        [canvasWindow fadeOut:lua_tonumber(L, 2) andDelete:YES withState:L];
    }

    lua_pushnil(L);
    return 1;
}

/// hs.canvas:isShowing() -> boolean
/// Method
/// Returns whether or not the canvas is currently being shown.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the canvas is currently being shown (true) or is currently hidden (false).
///
/// Notes:
///  * This method only determines whether or not the canvas is being shown or is hidden -- it does not indicate whether or not the canvas is currently off screen or is occluded by other objects.
///  * See also [hs.canvas:isOccluded](#isOccluded).
static int canvas_isShowing(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;
    if (parentIsWindow(canvasView)) {
        lua_pushboolean(L, [canvasWindow isVisible]) ;
    } else {
        lua_pushboolean(L, !canvasView.hidden && [canvasWindow isVisible]) ;
    }
    return 1 ;
}

/// hs.canvas:isOccluded() -> boolean
/// Method
/// Returns whether or not the canvas is currently occluded (hidden by other windows, off screen, etc).
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the canvas is currently being occluded.
///
/// Notes:
///  * If any part of the canvas is visible (even if that portion of the canvas does not contain any canvas elements), then the canvas is not considered occluded.
///  * a canvas which is completely covered by one or more opaque windows is considered occluded; however, if the windows covering the canvas are not opaque, then the canvas is not occluded.
///  * a canvas that is currently hidden or with a height of 0 or a width of 0 is considered occluded.
///  * See also [hs.canvas:isShowing](#isShowing).
static int canvas_isOccluded(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    HSCanvasWindow *canvasWindow = (HSCanvasWindow *)canvasView.window ;
    if (parentIsWindow(canvasView)) {
        lua_pushboolean(L, ([canvasWindow occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible) ;
    } else {
        lua_pushboolean(L, canvasView.hidden || (([canvasWindow occlusionState] & NSWindowOcclusionStateVisible) != NSWindowOcclusionStateVisible)) ;
    }
    return 1 ;
}

/// hs.canvas:canvasDefaultFor(keyName, [newValue]) -> canvasObject | currentValue
/// Method
/// Get or set the element default specified by keyName.
///
/// Parameters:
///  * `keyName` - the element default to examine or modify
///  * `value`   - an optional new value to set as the default fot his canvas when not specified explicitly in an element declaration.
///
/// Returns:
///  * If an argument is provided, the canvas object; otherwise the current value.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * Currently set and built-in defaults may be retrieved in a table with [hs.canvas:canvasDefaults](#canvasDefaults).
static int canvas_canvasDefaultFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;

    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSString *keyName = [skin toNSObjectAtIndex:2] ;

    if (!languageDictionary[keyName]) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
    }

    id attributeDefault = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
    if (!attributeDefault) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute %@ has no default value", keyName] UTF8String]) ;
    }

    if (lua_gettop(L) == 2) {
        [skin pushNSObject:attributeDefault] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:3 withOptions:LS_NSRawTables] ;

        switch([canvasView setDefaultFor:keyName to:keyValue withState:L]) {
            case attributeValid:
            case attributeNulling:
                break ;
            case attributeInvalid:
            default:
                if ([languageDictionary[keyName][@"nullable"] boolValue]) {
                    return luaL_argerror(L, 3, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
                } else {
                    return luaL_argerror(L, 2, [[NSString stringWithFormat:@"attribute default for %@ cannot be changed", keyName] UTF8String]) ;
                }
//                 break ;
        }

        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.canvas:insertElement(elementTable, [index]) -> canvasObject
/// Method
/// Insert a new element into the canvas at the specified index.
///
/// Parameters:
///  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
///  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index, and those that follow, will be moved one position up in the element array.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
///
/// Returns:
///  * the canvasObject
///
/// Notes:
///  * see also [hs.canvas:assignElement](#assignElement).
static int canvas_insertElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
    if ([element isKindOfClass:[NSDictionary class]]) {
        NSString *elementType = element[@"type"] ;
        if (elementType && [ALL_TYPES containsObject:elementType]) {
            [canvasView.elementList insertObject:[[NSMutableDictionary alloc] init] atIndex:(NSUInteger)tablePosition] ;
            [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                // skip type in here to minimize the need to copy in defaults just to be overwritten
                if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue withState:L] ;
            }] ;
            [canvasView setElementValueFor:@"type" atIndex:(NSUInteger)tablePosition to:elementType withState:L] ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
        }
    } else {
        return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.canvas:removeElement([index]) -> canvasObject
/// Method
/// Insert a new element into the canvas at the specified index.
///
/// Parameters:
///  * `index`        - an optional integer between 1 and the canvas element count specifying the index of the canvas element to remove. Any elements that follow, will be moved one position down in the element array.  Defaults to the canvas element count (i.e. the last element of the currently defined elements).
///
/// Returns:
///  * the canvasObject
static int canvas_removeElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 2) ? (lua_tointeger(L, 2) - 1) : (NSInteger)elementCount - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger realIndex = (NSUInteger)tablePosition ;
    if (realIndex < elementCount && canvasView.elementList[realIndex] && canvasView.elementList[realIndex][@"canvas"]) {
        [canvasView.elementList[realIndex][@"canvas"] removeFromSuperview] ;
    }
    [canvasView.elementList removeObjectAtIndex:realIndex] ;

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.canvas:elementAttribute(index, key, [value]) -> canvasObject | current value
/// Method
/// Get or set the attribute `key` for the canvas element at the specified index.
///
/// Parameters:
///  * `index` - the index of the canvas element whose attribute is to be retrieved or set.
///  * `key`   - the key name of the attribute to get or set.
///  * `value` - an optional value to assign to the canvas element's attribute.
///
/// Returns:
///  * if a value for the attribute is specified, returns the canvas object; otherwise returns the current value for the specified attribute.
static int canvas_elementAttributeAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TSTRING,
                    LS_TANY | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSString        *keyName      = [skin toNSObjectAtIndex:3] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    BOOL            resolvePercentages = NO ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    if (!languageDictionary[keyName]) {
        if (lua_gettop(L) == 3) {
            // check if keyname ends with _raw, if so we get with converted numeric values
            if ([keyName hasSuffix:@"_raw"]) {
                keyName = [keyName substringWithRange:NSMakeRange(0, [keyName length] - 4)] ;
                if (languageDictionary[keyName]) resolvePercentages = YES ;
            }
            if (!resolvePercentages) {
                lua_pushnil(L) ;
                return 1 ;
            }
        } else {
            return luaL_argerror(L, 3, [[NSString stringWithFormat:@"attribute name %@ unrecognized", keyName] UTF8String]) ;
        }
    }

    if (lua_gettop(L) == 3) {
        [skin pushNSObject:[canvasView getElementValueFor:keyName atIndex:(NSUInteger)tablePosition resolvePercentages:resolvePercentages onlyIfSet:NO]] ;
    } else {
        id keyValue = [skin toNSObjectAtIndex:4 withOptions:LS_NSRawTables] ;
        switch([canvasView setElementValueFor:keyName atIndex:(NSUInteger)tablePosition to:keyValue withState:L]) {
            case attributeValid:
            case attributeNulling:
                lua_pushvalue(L, 1) ;
                break ;
            case attributeInvalid:
            default:
                return luaL_argerror(L, 4, [[NSString stringWithFormat:@"invalid argument type for %@ specified", keyName] UTF8String]) ;
//                 break ;
        }
    }
    return 1 ;
}

/// hs.canvas:elementKeys(index, [optional]) -> table
/// Method
/// Returns a list of the key names for the attributes set for the canvas element at the specified index.
///
/// Parameters:
///  * `index`    - the index of the element to get the assigned key list from.
///  * `optional` - an optional boolean, default false, indicating whether optional, but unset, keys relevant to this canvas object should also be included in the list returned.
///
/// Returns:
///  * a table containing the keys that are set for this canvas element.  May also optionally include keys which are not specifically set for this element but use inherited values from the canvas or module defaults.
///
/// Notes:
///  * Any attribute which has been explicitly set for the element will be included in the key list (even if it is ignored for the element type).  If the `optional` flag is set to true, the *additional* attribute names added to the list will only include those which are relevant to the element type.
static int canvas_elementKeysAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = lua_tointeger(L, 2) - 1 ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 2, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }
    NSUInteger indexPosition = (NSUInteger)tablePosition ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.elementList[indexPosition] allKeys]] ;
    if ((lua_gettop(L) == 3) && lua_toboolean(L, 3)) {
        NSString *ourType = canvasView.elementList[indexPosition][@"type"] ;
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"optionalFor"] && [keyValue[@"optionalFor"] containsObject:ourType]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

/// hs.canvas:elementCount() -> integer
/// Method
/// Returns the number of elements currently defined for the canvas object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the number of elements currently defined for the canvas object.
static int canvas_elementCount(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    lua_pushinteger(L, (lua_Integer)[canvasView.elementList count]) ;
    return 1 ;
}

/// hs.canvas:canvasDefaults([module]) -> table
/// Method
/// Get a table of the default key-value pairs which apply to the canvas.
///
/// Parameters:
///  * `module` - an optional boolean flag, default false, indicating whether module defaults (true) should be included in the table.  If false, only those defaults which have been explicitly set for the canvas are returned.
///
/// Returns:
///  * a table containing key-value pairs for the defaults which apply to the canvas.
///
/// Notes:
///  * Not all keys will apply to all element types.
///  * To change the defaults for the canvas, use [hs.canvas:canvasDefaultFor](#canvasDefaultFor).
static int canvas_canvasDefaults(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        lua_newtable(L) ;
        for (NSString *keyName in languageDictionary) {
            id keyValue = [canvasView getDefaultValueFor:keyName onlyIfSet:NO] ;
            if (keyValue) {
                [skin pushNSObject:keyValue] ; lua_setfield(L, -2, [keyName UTF8String]) ;
            }
        }
    } else {
        [skin pushNSObject:canvasView.canvasDefaults withOptions:LS_NSDescribeUnknownTypes] ;
    }
    return 1 ;
}

/// hs.canvas:canvasDefaultKeys([module]) -> table
/// Method
/// Returns a list of the key names for the attributes set for the canvas defaults.
///
/// Parameters:
///  * `module` - an optional boolean flag, default false, indicating whether the key names for the module defaults (true) should be included in the list.  If false, only those defaults which have been explicitly set for the canvas are included.
///
/// Returns:
///  * a table containing the key names for the defaults which are set for this canvas. May also optionally include key names for all attributes which have a default value defined by the module.
static int canvas_canvasDefaultKeys(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    NSMutableSet *list = [[NSMutableSet alloc] initWithArray:[(NSDictionary *)canvasView.canvasDefaults allKeys]] ;
    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        [languageDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, NSDictionary *keyValue, __unused BOOL *stop) {
            if (keyValue[@"default"]) {
                [list addObject:keyName] ;
            }
        }] ;
    }
    [skin pushNSObject:list] ;
    return 1 ;
}

/// hs.canvas:canvasElements() -> table
/// Method
/// Returns an array containing the elements defined for this canvas.  Each array entry will be a table containing the key-value pairs which have been set for that canvas element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array of element tables which are defined for the canvas.
static int canvas_canvasElements(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    [skin pushNSObject:canvasView.elementList withOptions:LS_NSDescribeUnknownTypes] ;
    return 1 ;
}

/// hs.canvas:elementBounds(index) -> rectTable
/// Method
/// Returns the smallest rectangle which can fully contain the canvas element at the specified index.
///
/// Parameters:
///  * `index` - the index of the canvas element to get the bounds for
///
/// Returns:
///  * a rect table containing the smallest rectangle which can fully contain the canvas element.
///
/// Notes:
///  * For many elements, this will be the same as the element frame.  For items without a frame (e.g. `segments`, `circle`, etc.) this will be the smallest rectangle which can fully contain the canvas element as specified by it's attributes.
static int canvas_elementBoundsAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_tointeger(L, 2) - 1) ;

    if (tablePosition < 0 || tablePosition >= (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    NSUInteger   idx         = (NSUInteger)tablePosition ;
    NSRect       boundingBox = NSZeroRect ;
    NSBezierPath *itemPath   = [canvasView pathForElementAtIndex:idx] ;
    if (itemPath) {
        if ([itemPath isEmpty]) {
            boundingBox = NSZeroRect ;
        } else {
            boundingBox = [itemPath bounds] ;
        }
    } else {
        NSString *itemType = canvasView.elementList[idx][@"type"] ;
        if ([itemType isEqualToString:@"image"] || [itemType isEqualToString:@"text"] || [itemType isEqualToString:@"canvas"]) {
            NSDictionary *frame = [canvasView getElementValueFor:@"frame"
                                                         atIndex:idx
                                              resolvePercentages:YES] ;
            boundingBox = NSMakeRect([frame[@"x"] doubleValue], [frame[@"y"] doubleValue],
                                     [frame[@"w"] doubleValue], [frame[@"h"] doubleValue]) ;
        } else {
            lua_pushnil(L) ;
            return 1 ;
        }
    }
    [skin pushNSRect:boundingBox] ;
    return 1 ;
}

/// hs.canvas:assignElement(elementTable, [index]) -> canvasObject
/// Method
/// Assigns a new element to the canvas at the specified index.
///
/// Parameters:
///  * `elementTable` - a table containing key-value pairs that define the element to be added to the canvas.
///  * `index`        - an optional integer between 1 and the canvas element count + 1 specifying the index position to put the new element.  Any element currently at that index will be replaced.  Defaults to the canvas element count + 1 (i.e. after the end of the currently defined elements).
///
/// Returns:
///  * the canvasObject
///
/// Notes:
///  * When the index specified is the canvas element count + 1, the behavior of this method is the same as [hs.canvas:insertElement](#insertElement); i.e. it adds the new element to the end of the currently defined element list.
static int canvas_assignElementAtIndex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TTABLE | LS_TNIL,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    HSCanvasView   *canvasView   = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;

    NSUInteger      elementCount  = [canvasView.elementList count] ;
    NSInteger       tablePosition = (lua_gettop(L) == 3) ? (lua_tointeger(L, 3) - 1) : (NSInteger)elementCount ;

    if (tablePosition < 0 || tablePosition > (NSInteger)elementCount) {
        return luaL_argerror(L, 3, [[NSString stringWithFormat:@"index %ld out of bounds", tablePosition + 1] UTF8String]) ;
    }

    if (lua_isnil(L, 2)) {
        if (tablePosition == (NSInteger)elementCount - 1) {
            [canvasView.elementList removeLastObject] ;
        } else {
            return luaL_argerror(L, 3, "nil only valid for final element") ;
        }
    } else {
        NSDictionary *element = [skin toNSObjectAtIndex:2 withOptions:LS_NSRawTables] ;
        if ([element isKindOfClass:[NSDictionary class]]) {
            NSString *elementType = element[@"type"] ;
            if (elementType && [ALL_TYPES containsObject:elementType]) {
                NSUInteger realIndex = (NSUInteger)tablePosition ;
                if (realIndex < elementCount && canvasView.elementList[realIndex] && canvasView.elementList[realIndex][@"canvas"]) {
                    [canvasView.elementList[realIndex][@"canvas"] removeFromSuperview] ;
                }
                canvasView.elementList[realIndex] = [[NSMutableDictionary alloc] init] ;
                [element enumerateKeysAndObjectsUsingBlock:^(NSString *keyName, id keyValue, __unused BOOL *stop) {
                    // skip type in here to minimize the need to copy in defaults just to be overwritten
                    if (![keyName isEqualTo:@"type"]) [canvasView setElementValueFor:keyName atIndex:realIndex to:keyValue withState:L] ;
                }] ;
                [canvasView setElementValueFor:@"type" atIndex:realIndex to:elementType withState:L] ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"invalid type %@; must be one of %@", elementType, [ALL_TYPES componentsJoinedByString:@", "]] UTF8String]) ;
            }
        } else {
            return luaL_argerror(L, 2, "invalid element definition; must contain key-value pairs");
        }
    }

    canvasView.needsDisplay = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Module Constants

/// hs.canvas.compositeTypes[]
/// Constant
/// A table containing the possible compositing rules for elements within the canvas.
///
/// Compositing rules specify how an element assigned to the canvas is combined with the earlier elements of the canvas. The default compositing rule for the canvas is `sourceOver`, but each element of the canvas can be assigned a composite type which overrides this default for the specific element.
///
/// The available types are as follows:
///  * `clear`           - Transparent. (R = 0)
///  * `copy`            - Source image. (R = S)
///  * `sourceOver`      - Source image wherever source image is opaque, and destination image elsewhere. (R = S + D*(1 - Sa))
///  * `sourceIn`        - Source image wherever both images are opaque, and transparent elsewhere. (R = S*Da)
///  * `sourceOut`       - Source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da))
///  * `sourceAtop`      - Source image wherever both images are opaque, destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = S*Da + D*(1 - Sa))
///  * `destinationOver` - Destination image wherever destination image is opaque, and source image elsewhere. (R = S*(1 - Da) + D)
///  * `destinationIn`   - Destination image wherever both images are opaque, and transparent elsewhere. (R = D*Sa)
///  * `destinationOut`  - Destination image wherever destination image is opaque but source image is transparent, and transparent elsewhere. (R = D*(1 - Sa))
///  * `destinationAtop` - Destination image wherever both images are opaque, source image wherever source image is opaque but destination image is transparent, and transparent elsewhere. (R = S*(1 - Da) + D*Sa)
///  * `XOR`             - Exclusive OR of source and destination images. (R = S*(1 - Da) + D*(1 - Sa)). Works best with black and white images and is not recommended for color contexts.
///  * `plusDarker`      - Sum of source and destination images, with color values approaching 0 as a limit. (R = MAX(0, (1 - D) + (1 - S)))
///  * `plusLighter`     - Sum of source and destination images, with color values approaching 1 as a limit. (R = MIN(1, S + D))
///
/// In each equation, R is the resulting (premultiplied) color, S is the source color, D is the destination color, Sa is the alpha value of the source color, and Da is the alpha value of the destination color.
///
/// The `source` object is the individual element as it is rendered in order within the canvas, and the `destination` object is the combined state of the previous elements as they have been composited within the canvas.
static int pushCompositeTypes(lua_State *L) {
    [[LuaSkin sharedWithState:L] pushNSObject:COMPOSITING_TYPES] ;
    return 1 ;
}

/// hs.canvas.windowBehaviors[]
/// Constant
/// Array of window behavior labels for determining how a canvas or drawing object is handled in Spaces and Exposé
///
/// * `default`                   - The window can be associated to one space at a time.
/// * `canJoinAllSpaces`          - The window appears in all spaces. The menu bar behaves this way.
/// * `moveToActiveSpace`         - Making the window active does not cause a space switch; the window switches to the active space.
///
/// Only one of these may be active at a time:
///
/// * `managed`                   - The window participates in Spaces and Exposé. This is the default behavior if windowLevel is equal to NSNormalWindowLevel.
/// * `transient`                 - The window floats in Spaces and is hidden by Exposé. This is the default behavior if windowLevel is not equal to NSNormalWindowLevel.
/// * `stationary`                - The window is unaffected by Exposé; it stays visible and stationary, like the desktop window.
///
/// The following have no effect on `hs.canvas` or `hs.drawing` objects, but are included for completness and are expected to be used by future additions.
///
/// Only one of these may be active at a time:
///
/// * `participatesInCycle`       - The window participates in the window cycle for use with the Cycle Through Windows Window menu item.
/// * `ignoresCycle`              - The window is not part of the window cycle for use with the Cycle Through Windows Window menu item.
///
/// Only one of these may be active at a time:
///
/// * `fullScreenPrimary`         - A window with this collection behavior has a fullscreen button in the upper right of its titlebar.
/// * `fullScreenAuxiliary`       - Windows with this collection behavior can be shown on the same space as the fullscreen window.
///
/// Only one of these may be active at a time (Available in OS X 10.11 and later):
///
/// * `fullScreenAllowsTiling`    - A window with this collection behavior be a full screen tile window and does not have to have `fullScreenPrimary` set.
/// * `fullScreenDisallowsTiling` - A window with this collection behavior cannot be made a fullscreen tile window, but it can have `fullScreenPrimary` set.  You can use this setting to prevent other windows from being placed in the window’s fullscreen tile.
static int pushCollectionTypeTable(lua_State *L) {
    lua_newtable(L) ;
        lua_pushinteger(L, NSWindowCollectionBehaviorDefault) ;
        lua_setfield(L, -2, "default") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorCanJoinAllSpaces) ;
        lua_setfield(L, -2, "canJoinAllSpaces") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorMoveToActiveSpace) ;
        lua_setfield(L, -2, "moveToActiveSpace") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorManaged) ;
        lua_setfield(L, -2, "managed") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorTransient) ;
        lua_setfield(L, -2, "transient") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorStationary) ;
        lua_setfield(L, -2, "stationary") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorParticipatesInCycle) ;
        lua_setfield(L, -2, "participatesInCycle") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorIgnoresCycle) ;
        lua_setfield(L, -2, "ignoresCycle") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenPrimary) ;
        lua_setfield(L, -2, "fullScreenPrimary") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAuxiliary) ;
        lua_setfield(L, -2, "fullScreenAuxiliary") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAllowsTiling) ;
        lua_setfield(L, -2, "fullScreenAllowsTiling") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenDisallowsTiling) ;
        lua_setfield(L, -2, "fullScreenDisallowsTiling") ;
    return 1 ;
}

/// hs.canvas.windowLevels
/// Constant
/// A table of predefined window levels usable with [hs.canvas:level](#level)
///
/// Predefined levels are:
///  * _MinimumWindowLevelKey - lowest allowed window level
///  * desktop
///  * desktopIcon            - [hs.canvas:sendToBack](#sendToBack) is equivalent to this level - 1
///  * normal                 - normal application windows
///  * tornOffMenu
///  * floating               - equivalent to [hs.canvas:bringToFront(false)](#bringToFront); where "Always Keep On Top" windows are usually set
///  * modalPanel             - modal alert dialog
///  * utility
///  * dock                   - level of the Dock
///  * mainMenu               - level of the Menubar
///  * status
///  * popUpMenu              - level of a menu when displayed (open)
///  * overlay
///  * help
///  * dragging
///  * screenSaver            - equivalent to [hs.canvas:bringToFront(true)](#bringToFront)
///  * assistiveTechHigh
///  * cursor
///  * _MaximumWindowLevelKey - highest allowed window level
///
/// Notes:
///  * These key names map to the constants used in CoreGraphics to specify window levels and may not actually be used for what the name might suggest. For example, tests suggest that an active screen saver actually runs at a level of 2002, rather than at 1000, which is the window level corresponding to kCGScreenSaverWindowLevelKey.
///  * Each window level is sorted separately and [hs.canvas:orderAbove](#orderAbove) and [hs.canvas:orderBelow](#orderBelow) only arrange windows within the same level.
///  * If you use Dock hiding (or in 10.11, Menubar hiding) please note that when the Dock (or Menubar) is popped up, it is done so with an implicit orderAbove, which will place it above any items you may also draw at the Dock (or MainMenu) level.
///
///  * A canvas object with a [hs.canvas:draggingCallback](#draggingCallback) function can only accept drag-and-drop items when its window level is at `hs.canvas.windowLevels.dragging` or lower.
///  * A canvas object with a [hs.canvas:mouseCallback](#mouseCallback) function can only reliably receive mouse click events when its window level is at `hs.canvas.windowLevels.desktopIcon` + 1 or higher.
static int cg_windowLevels(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBaseWindowLevelKey)) ;              lua_setfield(L, -2, "kCGBaseWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ;           lua_setfield(L, -2, "_MinimumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopWindowLevelKey)) ;           lua_setfield(L, -2, "desktop") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBackstopMenuLevelKey)) ;            lua_setfield(L, -2, "kCGBackstopMenuLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGNormalWindowLevelKey)) ;            lua_setfield(L, -2, "normal") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGFloatingWindowLevelKey)) ;          lua_setfield(L, -2, "floating") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey)) ;       lua_setfield(L, -2, "tornOffMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDockWindowLevelKey)) ;              lua_setfield(L, -2, "dock") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMainMenuWindowLevelKey)) ;          lua_setfield(L, -2, "mainMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGStatusWindowLevelKey)) ;            lua_setfield(L, -2, "status") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGModalPanelWindowLevelKey)) ;        lua_setfield(L, -2, "modalPanel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey)) ;         lua_setfield(L, -2, "popUpMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDraggingWindowLevelKey)) ;          lua_setfield(L, -2, "dragging") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGScreenSaverWindowLevelKey)) ;       lua_setfield(L, -2, "screenSaver") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ;           lua_setfield(L, -2, "_MaximumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGOverlayWindowLevelKey)) ;           lua_setfield(L, -2, "overlay") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGHelpWindowLevelKey)) ;              lua_setfield(L, -2, "help") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGUtilityWindowLevelKey)) ;           lua_setfield(L, -2, "utility") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)) ;       lua_setfield(L, -2, "desktopIcon") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGCursorWindowLevelKey)) ;            lua_setfield(L, -2, "cursor") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey)) ; lua_setfield(L, -2, "assistiveTechHigh") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGNumberOfWindowLevelKeys)) ;         lua_setfield(L, -2, "kCGNumberOfWindowLevelKeys") ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSCanvasView(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasView *value = obj;
    if (value.selfRef == LUA_NOREF) {
        void** valuePtr = lua_newuserdata(L, sizeof(HSCanvasView *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
        value.selfRef = [skin luaRef:refTable] ;
    }
    [skin pushLuaRef:refTable ref:value.selfRef] ;
    return 1;
}

static id toHSCanvasViewFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasView *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCanvasView, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasView *obj = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
    NSString *title ;
    if (parentIsWindow(obj)) {
        title = NSStringFromRect(RectWithFlippedYCoordinate(obj.window.frame)) ;
    } else {
        title = NSStringFromRect(obj.frame) ;
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSCanvasView *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCanvasView"] ;
        HSCanvasView *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCanvasView"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSCanvasView *theView = get_objectFromUserdata(__bridge_transfer HSCanvasView, L, 1, USERDATA_TAG) ;
    if (theView) {
        if (!parentIsWindow(theView)) [theView removeFromSuperview] ;
        theView.mouseCallbackRef    = [skin luaUnref:refTable ref:theView.mouseCallbackRef] ;
        theView.draggingCallbackRef = [skin luaUnref:refTable ref:theView.draggingCallbackRef] ;

        theView.selfRef          = [skin luaUnref:refTable ref:theView.selfRef] ;

        NSDockTile *tile     = [[NSApplication sharedApplication] dockTile];
        NSView     *tileView = tile.contentView ;
        if (tileView && [theView isEqualTo:tileView]) tile.contentView = nil ;

        HSCanvasWindow *theWindow = theView.wrapperWindow ;
        if (theWindow) [theWindow close];
        theView.wrapperWindow    = nil ;
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
// affects drawing elements
    {"assignElement",         canvas_assignElementAtIndex},
    {"canvasElements",        canvas_canvasElements},
    {"canvasDefaults",        canvas_canvasDefaults},
    {"canvasMouseEvents",     canvas_canvasMouseEvents},
    {"canvasDefaultKeys",     canvas_canvasDefaultKeys},
    {"canvasDefaultFor",      canvas_canvasDefaultFor},
    {"elementAttribute",      canvas_elementAttributeAtIndex},
    {"elementBounds",         canvas_elementBoundsAtIndex},
    {"elementCount",          canvas_elementCount},
    {"elementKeys",           canvas_elementKeysAtIndex},
    {"imageFromCanvas",       canvas_canvasAsImage},
    {"insertElement",         canvas_insertElementAtIndex},
    {"minimumTextSize",       canvas_getTextElementSize},
    {"removeElement",         canvas_removeElementAtIndex},
// affects whole canvas
    {"alpha",                 canvas_alpha},
    {"behavior",              canvas_behavior},
    {"clickActivating",       canvas_clickActivating},
    {"delete",                canvas_delete},
    {"hide",                  canvas_hide},
    {"isOccluded",            canvas_isOccluded},
    {"isShowing",             canvas_isShowing},
    {"level",                 canvas_level},
    {"mouseCallback",         canvas_mouseCallback},
    {"orderAbove",            canvas_orderAbove},
    {"orderBelow",            canvas_orderBelow},
    {"show",                  canvas_show},
    {"size",                  canvas_size},
    {"topLeft",               canvas_topLeft},
    {"transformation",        canvas_canvasTransformation},
    {"wantsLayer",            canvas_wantsLayer},
    {"draggingCallback",      canvas_draggingCallback},

    {"_accessibilitySubrole", canvas_accessibilitySubrole},

    {"__tostring",            userdata_tostring},
    {"__eq",                  userdata_eq},
    {"__gc",                  userdata_gc},
    {NULL,                    NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"defaultTextStyle",     default_textAttributes},
    {"elementSpec",          dumpLanguageDictionary},
    {"new",                  canvas_new},
    {"useCustomAccessibilitySubrole", canvas_useCustomAccessibilitySubrole},

    {NULL,                   NULL}
};

int luaopen_hs_canvas_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    languageDictionary = defineLanguageDictionary() ;

    [skin registerPushNSHelper:pushHSCanvasView         forClass:"HSCanvasView"];
    [skin registerLuaObjectHelper:toHSCanvasViewFromLua forClass:"HSCanvasView"
                                              withUserdataMapping:USERDATA_TAG];

    pushCompositeTypes(L) ;      lua_setfield(L, -2, "compositeTypes") ;
    pushCollectionTypeTable(L) ; lua_setfield(L, -2, "windowBehaviors") ;
    cg_windowLevels(L) ;         lua_setfield(L, -2, "windowLevels") ;

    // in case we're reloaded, return to default state
    defaultCustomSubRole = YES ;

    return 1;
}
