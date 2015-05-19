//  ASCIImage
//  Created by Charles Parnot on 5/29/13.
//  Copyright (c) 2013 Charles Parnot. All rights reserved.


#import "PARImage+ASCIIInput.h"

NSString * const ASCIIContextShapeIndex         = @"ASCIIContextShapeIndex";
NSString * const ASCIIContextFillColor          = @"ASCIIContextFillColor";
NSString * const ASCIIContextStrokeColor        = @"ASCIIContextStrokeColor";
NSString * const ASCIIContextLineWidth          = @"ASCIIContextLineWidth";
NSString * const ASCIIContextShouldClose        = @"ASCIIContextShouldClose";
NSString * const ASCIIContextShouldAntialias    = @"ASCIIContextShouldAntialias";


#pragma mark - PARImage Cross-Platform Image Class

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR

    #define PARImage      UIImage
    #define PARColor      UIColor
    #define PARBezierPath UIBezierPath
    #define NSStringFromPoint(point) (NSStringFromCGPoint(point))
    #define PARValueFromPoint(point) ([NSValue valueWithCGPoint:(point)])
    #define PARPointFromValue(value) ([value CGPointValue])
    #define lineToPoint addLineToPoint
    #define NSMiterLineJoinStyle kCGLineJoinMiter
    #define NSSquareLineCapStyle kCGLineCapSquare

#elif TARGET_OS_MAC

    #define PARImage NSImage
    #define PARColor      NSColor
    #define PARBezierPath NSBezierPath
    #define PARValueFromPoint(point) ([NSValue valueWithPoint:(point)])
    #define PARPointFromValue(value) ([value pointValue])

#endif

#pragma mark - PARShape

// shape = polygon or ellipse
// a polygon represents an array of pixels, that would eventually be drawn by joining the points in order

@interface PARShape : NSObject
+ (PARShape *)polygonWithPointValues:(NSArray *)pointValues;
+ (PARShape *)ellipseWithPointValues:(NSArray *)pointValues;
@property (readonly) PARBezierPath *bezierPath;
@property (readonly) PARBezierPath *closedBezierPath;
@property (readonly, copy) NSArray *pointValues;
@property (readonly) BOOL ellipse;
@end


#pragma mark - Cross-Platform Methods

@implementation PARImage (ASCIIInput)

#pragma mark - ASCII --> Strict ASCII

+ (NSArray *)strictASCIIRepresentationFromLenientASCIIRepresentation:(NSArray *)lenientRep
{
    // empty input
    if ([lenientRep count] == 0)
    {
        NSLog(@"ERROR: empty ASCII shape:\n%@", [lenientRep componentsJoinedByString:@"\n"]);
        return nil;
    }
    
    // consistent data?
    NSSet *counts = [NSSet setWithArray:[lenientRep valueForKey:@"length"]];
    if (counts.count != 1)
    {
        NSLog(@"ERROR: inconsistent line sizes '%@' in ASCII shape:\n%@", [[counts allObjects] componentsJoinedByString:@","], [lenientRep componentsJoinedByString:@"\n"]);
        return nil;
    }
    
    // empty lines
    NSUInteger columnCount = [counts.anyObject unsignedIntegerValue];
    if (columnCount == 0)
    {
        NSLog(@"ERROR: empty lines in ASCII shape:\n%@", [lenientRep componentsJoinedByString:@"\n"]);
        return nil;
    }
    
    // merge all the strings for easier processing
    NSString *concatenatedStrings = [lenientRep componentsJoinedByString:@""];
    NSUInteger total = concatenatedStrings.length;
    
    // detect "pixels" = non-space characters
    NSMutableIndexSet *pixelColumns = [NSMutableIndexSet indexSet];
    NSCharacterSet *nonSpace = [self nonWhitespaceCharacters];
    NSRange searchRange = [concatenatedStrings rangeOfCharacterFromSet:nonSpace options:NSLiteralSearch range:NSMakeRange(0, total)];
    while (searchRange.location != NSNotFound)
    {
        [pixelColumns addIndex:(searchRange.location % columnCount)];
        NSUInteger newLocation = searchRange.location + 1;
        if (newLocation < total)
            searchRange = [concatenatedStrings rangeOfCharacterFromSet:nonSpace options:NSLiteralSearch range:NSMakeRange(newLocation, total - newLocation)];
        else
            break;
    }
    
    // gaps between pixels
    NSMutableIndexSet *gaps = [NSMutableIndexSet indexSet];
    NSUInteger firstColumn = pixelColumns.firstIndex;
    NSUInteger currentColumn = firstColumn;
    while (currentColumn != NSNotFound)
    {
        NSUInteger nextColumn = [pixelColumns indexGreaterThanIndex:currentColumn];
        if (nextColumn == NSNotFound)
            break;
        [gaps addIndex:nextColumn -currentColumn];
        currentColumn = nextColumn;
    }
    
    // pixels should be regularly spaced: the actual gap is the greater common divisor
    // no need to make that a fancy algorithm, let's just enumarate all possible values going down, and including, the smallest gap
    NSUInteger smallestGap = gaps.firstIndex;
    if (smallestGap == NSNotFound)
        smallestGap = 1;
    NSUInteger pixelGap = 1;
    for (NSUInteger i = smallestGap; i > 1; i --)
    {
        NSUInteger gap = gaps.firstIndex;
        while (gap != NSNotFound && gap % i == 0)
        {
            gap = [gaps indexGreaterThanIndex:gap];
        }
        if (gap != NSNotFound)
            continue;
        
        // yes, the value 'i' divides all the gaps we collected: it is the greater common divisor!
        // if we never get there, the common divisor will be 1, which is always correct
        pixelGap = i;
        break;
    }
    
    // now, we know all about the layout of the pixels in the input, we can remove all the spaces and have exactly one character per pixel
    NSUInteger lastColumn = pixelColumns.lastIndex;
    NSUInteger countCols = 1 + (lastColumn - firstColumn) / pixelGap;
    NSUInteger countRows = lenientRep.count;
    NSAssert(((lastColumn - firstColumn) % pixelGap) == 0, @"the first and last pixel column should be spearated by an integer multiple of `pixelGap`");
    if (concatenatedStrings.length == countCols * countRows)
        return lenientRep;
    NSMutableString *strictString = [NSMutableString stringWithCapacity:countCols * countRows];
    for (NSUInteger i = 0; i < countRows; i ++)
    {
        for (NSUInteger j = 0; j < countCols; j ++)
            [strictString appendString:[concatenatedStrings substringWithRange:NSMakeRange(i * columnCount + firstColumn + j * pixelGap, 1)]];
    }
    NSAssert(strictString.length == countCols * countRows, @"String derived from lenient ascii shape should have %@ characters but is: %@", @(countCols * countRows), strictString);
    
    // final array
    NSMutableArray *strictRep = [NSMutableArray arrayWithCapacity:countRows];
    for (NSUInteger i = 0; i < countRows; i ++)
        [strictRep addObject:[strictString substringWithRange:NSMakeRange(countCols * i, countCols)]];
    return [NSArray arrayWithArray:strictRep];
}


#pragma mark - ASCII --> Ellipses + Polygons

+ (NSArray *)orderedMarksForASCIIShape
{
    static dispatch_once_t onceToken;
    static NSArray *orderedMarksForASCIIShape = nil;
    dispatch_once(&onceToken, ^
      {
          NSString *numbers = @"1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z a b c d e f g h i j k l m n p q r s t u v w x y z";
          orderedMarksForASCIIShape = [numbers componentsSeparatedByString:@" "];
      });
    return orderedMarksForASCIIShape;
}

+ (NSCharacterSet *)markCharactersForASCIIShape
{
    static dispatch_once_t onceToken;
    static NSCharacterSet *markCharactersForASCIIShape = nil;
    dispatch_once(&onceToken, ^
      {
          NSString *allMarks = [[self orderedMarksForASCIIShape] componentsJoinedByString:@""];
          markCharactersForASCIIShape = [NSCharacterSet characterSetWithCharactersInString:allMarks];
      });
    return markCharactersForASCIIShape;
}

+ (NSCharacterSet *)nonWhitespaceCharacters
{
    static dispatch_once_t onceToken;
    static NSCharacterSet *nonWhitespaceCharacters = nil;
    dispatch_once(&onceToken, ^
      {
          nonWhitespaceCharacters = [[NSCharacterSet whitespaceCharacterSet] invertedSet];
      });
    return nonWhitespaceCharacters;
}

+ (NSArray *)shapesFromNumbersInStrictASCIIRepresentation:(NSArray *)representation
{
    // canvas size
    NSUInteger countRows = representation.count;
    if (countRows == 0)
        return @[];
    NSUInteger countCols = [representation[0] length];
    NSUInteger countPixels = countRows * countCols;
    NSString *asciiString = [representation componentsJoinedByString:@""];
    
    // collect positions of the different marks in the shape
    NSCharacterSet *markCharacters = [self markCharactersForASCIIShape];
    NSRange markRange = [asciiString rangeOfCharacterFromSet:markCharacters options:NSLiteralSearch range:NSMakeRange(0, countPixels)];
    NSMutableDictionary *markPositions = [NSMutableDictionary dictionary];
    while (markRange.location != NSNotFound)
    {
        NSString *mark = [asciiString substringWithRange:markRange];
        NSMutableArray *positions = markPositions[mark];
        if (!positions)
        {
            positions = [NSMutableArray array];
            markPositions[mark] = positions;
        }
        
        // new position: note that the Y need to be inverted to get the coordinate rights
        CGFloat x = markRange.location % countCols;
        CGFloat y = countRows - 1 - markRange.location / countCols;
        [positions addObject:PARValueFromPoint(CGPointMake(x,y))];
        
        // next mark
        NSUInteger newLocation = markRange.location + 1;
        if (newLocation < countPixels)
            markRange = [asciiString rangeOfCharacterFromSet:markCharacters options:NSLiteralSearch range:NSMakeRange(newLocation, countPixels - newLocation)];
        else
            break;
    }
    
    // iterate over the possible marks (1, 2, 3, ...), building shapes as we go
    NSMutableArray *shapes = [NSMutableArray array];
    NSArray *marks = [self orderedMarksForASCIIShape];
    NSMutableArray *currentPoints = nil;
    for (NSString *mark in marks)
    {
        NSArray *points = markPositions[mark];
        NSUInteger numberOfPoints = points.count;
        
        // continue current shape of start a new one
        if (numberOfPoints == 1)
        {
            CGPoint vertex = PARPointFromValue(points.lastObject);
            if (!currentPoints)
                currentPoints = [NSMutableArray array];
            [currentPoints addObject:PARValueFromPoint(vertex)];
        }
        
        else
        {
            // close current shape
            if (currentPoints)
                [shapes addObject:[PARShape polygonWithPointValues:currentPoints]];
            currentPoints = nil;
            
            // single pixel
            if (numberOfPoints == 1)
                [shapes addObject:[PARShape polygonWithPointValues:points]];
            
            // line
            else if (numberOfPoints == 2)
                [shapes addObject:[PARShape polygonWithPointValues:points]];
            
            // ellipse
            else if (numberOfPoints > 2)
                [shapes addObject:[PARShape ellipseWithPointValues:points]];
        }
    }
    
    if (currentPoints)
        [shapes addObject:[PARShape polygonWithPointValues:currentPoints]];
    
    return [NSArray arrayWithArray:shapes];
}

// method used for testing
+ (NSArray *)numberedASCIIRepresentationFromASCIIRepresentation:(NSArray *)rep
{
    // ASCII --> shapes
    NSArray *strictRep = [self strictASCIIRepresentationFromLenientASCIIRepresentation:rep];
    NSArray *shapes = [self shapesFromNumbersInStrictASCIIRepresentation:strictRep];
    
    // prepare output
    NSUInteger countRows = strictRep.count;
    NSUInteger countCols = [strictRep[0] length];
    NSMutableArray *output = [NSMutableArray arrayWithCapacity:countRows];
    for (NSUInteger row = 0; row < countRows; row ++)
    {
        NSMutableString *line = [NSMutableString stringWithCapacity:countCols * 2];
        for (NSUInteger col = 0; col < countCols; col ++)
            [line appendString:@"· "];
        [output addObject:line];
    }
    
    // shapes --> ASCII
    NSArray *marks = [self orderedMarksForASCIIShape];
    NSUInteger currentMark = 0;
    for (PARShape *shape in shapes)
    {
        for (NSValue *value in shape.pointValues)
        {
            CGPoint point = PARPointFromValue(value);
            NSInteger x = point.x;
            NSInteger y = countCols - point.y;
            NSMutableString *line = output[y];
            [line replaceCharactersInRange:NSMakeRange(x * 2, 1) withString:marks[currentMark]];
            currentMark ++;
        }
        currentMark ++;
    }
    
    return output;
}



#pragma mark - ASCII --> NSImage

+ (void(^)(NSMutableDictionary *context))contextHandlerForImageWithColor:(PARColor *)color shouldAntialias:(BOOL)shouldAntialias
{
    return ^(NSMutableDictionary *context)
    {
        context[ASCIIContextShouldAntialias] = @(shouldAntialias);
        context[ASCIIContextFillColor] = color;
        context[ASCIIContextShouldClose] = @(YES);
    };
}

+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep color:(PARColor *)color shouldAntialias:(BOOL)shouldAntialias
{
    return [self imageWithASCIIRepresentation:rep contextHandler:[self contextHandlerForImageWithColor:color shouldAntialias:shouldAntialias]];
}

+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep contextHandler:(void(^)(NSMutableDictionary *context))contextHandler
{
    #if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
        
        CGFloat scaleFactor = [UIScreen mainScreen].scale;
        return [self ios_imageWithASCIIRepresentation:rep scaleFactor:scaleFactor contextHandler:contextHandler];
        
    #elif TARGET_OS_MAC
        
        return [self mac_imageWithASCIIRepresentation:rep contextHandler:contextHandler];
        
    #endif
}



#pragma mark - Predefined images

+ (PARImage *)arrowImageWithColor:(PARColor *)color
{
    NSArray *asciiRep = @
    [
     @"· · · · · · · · · · · ·",
     @"· · · · · · · · · · · ·",
     @"· · · · · · · · · · · ·",
     @"· · · · · · 1 · · · · ·",
     @"· · · · · · o o · · · ·",
     @"· · · 7 o o 8 o 2 · · ·",
     @"· · · 6 o o 5 o 3 · · ·",
     @"· · · · · · o o · · · ·",
     @"· · · · · · 4 · · · · ·",
     @"· · · · · · · · · · · ·",
     @"· · · · · · · · · · · ·",
     @"· · · · · · · · · · · ·",
     ];
    return [self imageWithASCIIRepresentation:asciiRep color:color shouldAntialias:NO];
}

+ (PARImage *)chevronImageWithColor:(PARColor *)color
{
    NSArray *asciiRep = @
    [
     @"· · · · · · · · · · · ·",
     @"· · · 1 2 · · · · · · ·",
     @"· · · A o o · · · · · ·",
     @"· · · · o o o · · · · ·",
     @"· · · · · o o o · · · ·",
     @"· · · · · · 9 o 3 · · ·",
     @"· · · · · · 8 o 4 · · ·",
     @"· · · · · o o o · · · ·",
     @"· · · · o o o · · · · ·",
     @"· · · 7 o o · · · · · ·",
     @"· · · 6 5 · · · · · · ·",
     @"· · · · · · · · · · · ·",
     ];
    return [self imageWithASCIIRepresentation:asciiRep color:color shouldAntialias:NO];
}


#pragma mark - Platform Specific Methods


#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR

+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep scaleFactor:(CGFloat)scaleFactor color:(PARColor *)color shouldAntialias:(BOOL)shouldAntialias
{
    return [self ios_imageWithASCIIRepresentation:rep scaleFactor:scaleFactor contextHandler:[self contextHandlerForImageWithColor:color shouldAntialias:shouldAntialias]];
}

+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep scaleFactor:(CGFloat)scaleFactor contextHandler:(void(^)(NSMutableDictionary *context))contextHandler
{
    return [self ios_imageWithASCIIRepresentation:rep scaleFactor:scaleFactor contextHandler:contextHandler];
}

+ (PARImage *)ios_imageWithASCIIRepresentation:(NSArray *)rep scaleFactor:(CGFloat)scale contextHandler:(void(^)(NSMutableDictionary *context))contextHandler
{
    // ASCII --> shapes
    NSArray *strictRep = [self strictASCIIRepresentationFromLenientASCIIRepresentation:rep];
    NSArray *shapes = [self shapesFromNumbersInStrictASCIIRepresentation:strictRep];
    
    // image size in points
    NSUInteger countRows = strictRep.count;
    NSUInteger countCols = [strictRep[0] length];
    CGSize imageSizeInPoints = CGSizeMake(countCols, countRows);
    
    // image size in pixels
    CGSize imageSizeInPixels;
    imageSizeInPixels.width  = imageSizeInPoints.width  * scale;
    imageSizeInPixels.height = imageSizeInPoints.height * scale;
    
    // iOS documentation: https://developer.apple.com/library/ios/documentation/2DDrawing/Conceptual/DrawingPrintingiOS/HandlingImages/Images.html
    // iOS example: http://kalyanchakravarthy.net/blog/ios-drawing-using-coregraphics.html
    
    
    // Create context for drawing to image
    UIGraphicsBeginImageContext(imageSizeInPixels);
    CGContextRef contextRef = UIGraphicsGetCurrentContext();
    
    // on iOS the Y axis is upside down
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, imageSizeInPixels.height);
    CGContextConcatCTM(contextRef, flipVertical);
    
    // scaling factor: the bezier paths are set in points, but we are drawing directly at the pixel size
    CGAffineTransform scalingTransform = CGAffineTransformMakeScale(scale, scale);
    CGContextConcatCTM(contextRef, scalingTransform);
    
    // drawing each shape
    NSUInteger shapeIndex = 0;
    for (PARShape *shape in shapes)
    {
        // get ASCII context from handler (that's different from the graphics context!)
        // ... but don't let the handler mess up the graphics context
        NSMutableDictionary *contextASCII = [NSMutableDictionary dictionaryWithDictionary:@{ASCIIContextShapeIndex: @(shapeIndex)}];
        CGContextSaveGState(contextRef);
        {
            contextHandler(contextASCII);
        }
        CGContextRestoreGState(contextRef);
        
        // get information from ASCII context
        PARColor *fillColor = contextASCII[ASCIIContextFillColor];
        PARColor *strokeColor = contextASCII[ASCIIContextStrokeColor];
        CGFloat lineWidth = [contextASCII[ASCIIContextLineWidth] floatValue];
        BOOL shouldClose = [contextASCII[ASCIIContextShouldClose] boolValue];
        BOOL shouldAntialias = [contextASCII[ASCIIContextShouldAntialias] boolValue];
        
        // bezier path from shape
        PARBezierPath *path = shouldClose ? [shape closedBezierPath] : [shape bezierPath];

        // antialias
        CGContextSetShouldAntialias(contextRef, shouldAntialias);
        
        // fill
        if (fillColor)
        {
            [fillColor setFill];
            [path fill];
            if (strokeColor == nil)
            {
                path.lineWidth = shouldAntialias ? 1.0 : sqrtf(2.0)/2.0;
                [fillColor setStroke];
                [path stroke];
            }
        }
        
        // stroke
        if (strokeColor)
        {
            path.lineWidth = lineWidth > 0.0 ? lineWidth : 1.0;
            [strokeColor setStroke];
            [path stroke];
        }
        shapeIndex ++;
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}


#elif TARGET_OS_MAC

+ (PARImage *)mac_imageWithASCIIRepresentation:(NSArray *)rep contextHandler:(void(^)(NSMutableDictionary *context))contextHandler
{
    // ASCII --> shapes
    NSArray *strictRep = [self strictASCIIRepresentationFromLenientASCIIRepresentation:rep];
    NSArray *shapes = [self shapesFromNumbersInStrictASCIIRepresentation:strictRep];
    
    // image size
    NSUInteger countRows = strictRep.count;
    NSUInteger countCols = [strictRep[0] length];
    NSSize imageSize = NSMakeSize(countCols, countRows);
    
    // image is drawn using the block API, so we can handle @2x drawing in HiDPI
    NSImage *image = [NSImage imageWithSize:imageSize flipped:NO drawingHandler:^BOOL(NSRect dstRect)
      {
          NSUInteger shapeIndex = 0;
          for (PARShape *shape in shapes)
          {
              // get ASCII context from handler (that's different from the graphics context!)
              // ... but don't let the handler mess up the graphics context
              NSMutableDictionary *contextASCII = [NSMutableDictionary dictionaryWithDictionary:@{ASCIIContextShapeIndex: @(shapeIndex)}];
              [[NSGraphicsContext currentContext] saveGraphicsState];
              {
                  contextHandler(contextASCII);
              }
              [[NSGraphicsContext currentContext] restoreGraphicsState];
              
              // get information from ASCII context
              PARColor *fillColor   = contextASCII[ASCIIContextFillColor];
              PARColor *strokeColor = contextASCII[ASCIIContextStrokeColor];
              CGFloat lineWidth     = [contextASCII[ASCIIContextLineWidth] floatValue];
              BOOL shouldClose      = [contextASCII[ASCIIContextShouldClose] boolValue];
              BOOL shouldAntialias  = [contextASCII[ASCIIContextShouldAntialias] boolValue];
              
              // bezier path from shape
              PARBezierPath *path = shouldClose ? [shape closedBezierPath] : [shape bezierPath];

              // draw!
              [[NSGraphicsContext currentContext] saveGraphicsState];
              {
                  // antialias
                  [[NSGraphicsContext currentContext] setShouldAntialias:shouldAntialias];
                  
                  // fill
                  if (fillColor)
                  {
                      [fillColor setFill];
                      [path fill];
                      if (strokeColor == nil)
                      {
                          path.lineWidth = shouldAntialias ? 1.0 : sqrtf(2.0)/2.0;
                          [fillColor setStroke];
                          [path stroke];
                      }
                  }
                  
                  // stroke
                  if (strokeColor)
                  {
                      path.lineWidth = lineWidth > 0.0 ? lineWidth : 1.0;
                      [strokeColor setStroke];
                      [path stroke];
                  }
              }
              [[NSGraphicsContext currentContext] restoreGraphicsState];
              shapeIndex ++;
          }
          
          return YES;
      }];
    
    return image;
    
}

#endif

@end



#pragma mark - PARShape Private Implementation

@interface PARShape ()
@property (readwrite, copy) NSArray *pointValues;
@property (readwrite) BOOL ellipse;
@property (readwrite) BOOL shouldClose;
@end

@implementation PARShape

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@:%p> (%@)", self.class, self, self.ellipse ? @"ellipse":@"polygon"];
    for (NSValue *value in self.pointValues)
    {
        [description appendString:@"\n"];
        [description appendString:NSStringFromPoint(PARPointFromValue(value))];
    }
    return [NSString stringWithString:description];
}

+ (PARShape *)polygonWithPointValues:(NSArray *)pointValues
{
    PARShape *polygon = [[PARShape alloc] init];
    polygon.pointValues = pointValues;
    return polygon;
}

+ (PARShape *)ellipseWithPointValues:(NSArray *)pointValues
{
    PARShape *polygon = [[PARShape alloc] init];
    polygon.pointValues = pointValues;
    polygon.ellipse = YES;
    return polygon;
}

- (PARBezierPath *)bezierPathClosed:(BOOL)shouldClose
{
    // ellipse
    if (self.ellipse)
    {
        NSArray *points = self.pointValues;
        CGPoint point1 = PARPointFromValue(points[0]);
        CGRect enclosingRect = CGRectMake(point1.x, point1.y, 0.0, 0.0);
        for (NSValue *pointValue in points)
        {
            CGPoint point = PARPointFromValue(pointValue);
            CGFloat minX = fminf(point.x, CGRectGetMinX(enclosingRect));
            CGFloat maxX = fmaxf(point.x, CGRectGetMaxX(enclosingRect));
            CGFloat minY = fminf(point.y, CGRectGetMinY(enclosingRect));
            CGFloat maxY = fmaxf(point.y, CGRectGetMaxY(enclosingRect));
            enclosingRect = CGRectMake(minX, minY, maxX - minX, maxY - minY);
        }
        enclosingRect.size.width  += 1.0;
        enclosingRect.size.height += 1.0;
        enclosingRect = CGRectInset(enclosingRect, 0.5, 0.5);
        return [PARBezierPath bezierPathWithOvalInRect:enclosingRect];
    }
    
    // polygon
    else
    {
        NSArray *points = self.pointValues;
        
        // single pixel
        if (points.count == 1)
        {
            CGPoint point = PARPointFromValue(points[0]);
            return [PARBezierPath bezierPathWithRect:CGRectMake(point.x + 0.49, point.y + 0.49, 0.02, 0.02)];
        }
        
        PARBezierPath *path = [PARBezierPath bezierPath];
        for (NSValue *pointValue in points)
        {
            CGPoint point = PARPointFromValue(pointValue);
            point.x += 0.5;
            point.y += 0.5;
            if ([path isEmpty])
                [path moveToPoint:point];
            else
                [path lineToPoint:point];
        }
        path.lineJoinStyle = NSMiterLineJoinStyle;
        path.lineCapStyle  = NSSquareLineCapStyle;
        if (points.count > 2 && shouldClose)
        {
            [path closePath];
        }
        return path;
    }
    
    return nil;
}

- (PARBezierPath *)bezierPath
{
    return [self bezierPathClosed:NO];
}

- (PARBezierPath *)closedBezierPath
{
    return [self bezierPathClosed:YES];
}

@end
