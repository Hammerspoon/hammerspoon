//
// NSImageView alignment, scale, and framing functions
//
// This file contains functions to replicate NSImageView functionality without actually
// forcing the image to be handled by a subview.
//
// Portions of this file are modified from code found in the GNUStep, project at https://github.com/gnustep/gui
// Primarily, but not necessarily limited to:
//    * Source/NSImageView.m
//    * Source/NSImageCell.m
//
#import "Canvas.h"

static inline CGFloat xLeftInRect(__unused NSSize innerSize, NSRect outerRect) {
    return NSMinX(outerRect);
}

static inline CGFloat xCenterInRect(NSSize innerSize, NSRect outerRect) {
    return NSMidX(outerRect) - (innerSize.width/2.0);
}

static inline CGFloat xRightInRect(NSSize innerSize, NSRect outerRect) {
    return NSMaxX(outerRect) - innerSize.width;
}

static inline CGFloat yTopInRect(NSSize innerSize, NSRect outerRect, BOOL flipped) {
    if (flipped)
        return NSMinY(outerRect);
    else
        return NSMaxY(outerRect) - innerSize.height;
}

static inline CGFloat yCenterInRect(NSSize innerSize, NSRect outerRect, __unused BOOL flipped) {
    return NSMidY(outerRect) - innerSize.height/2.0;
}

static inline CGFloat yBottomInRect(NSSize innerSize, NSRect outerRect, BOOL flipped) {
    if (flipped)
        return NSMaxY(outerRect) - innerSize.height;
    else
        return NSMinY(outerRect);
}

static inline NSSize scaleProportionally(NSSize imageSize, NSSize canvasSize, BOOL scaleUpOrDown) {
    CGFloat ratio;
    if (imageSize.width <= 0 || imageSize.height <= 0) {
        return NSMakeSize(0, 0);
    }
    /* Get the smaller ratio and scale the image size by it.  */
    ratio = fmin(canvasSize.width / imageSize.width, canvasSize.height / imageSize.height);
    /* Only scale down, unless scaleUpOrDown is YES */
    if (ratio < 1.0 || scaleUpOrDown) {
        imageSize.width *= ratio;
        imageSize.height *= ratio;
    }
    return imageSize;
}

@implementation HSCanvasView (imageAdditions)

- (NSSize) _scaleImageWithSize: (NSSize)imageSize
                   toFitInSize: (NSSize)canvasSize
                   scalingType: (NSImageScaling)scalingType {
    NSSize result;
    switch (scalingType) {
        case NSImageScaleProportionallyDown: // == NSScaleProportionally:
              result = scaleProportionally (imageSize, canvasSize, NO);
              break;
        case NSImageScaleAxesIndependently: // == NSScaleToFit
              result = canvasSize;
              break;
        default:
        case NSImageScaleNone: // == NSScaleNone
              result = imageSize;
              break;
        case NSImageScaleProportionallyUpOrDown:
              result = scaleProportionally (imageSize, canvasSize, YES);
              break;
    }
    return result;
}

- (NSRect) realRectFor:(NSImage *)theImage inFrame:(NSRect)cellFrame
                                       withScaling:(NSImageScaling)scaleStyle
                                     withAlignment:(NSImageAlignment)alignmentStyle {

    NSPoint position;
    BOOL    is_flipped = [self isFlipped];
    NSSize  imageSize ;

    imageSize = [self _scaleImageWithSize:[theImage size] toFitInSize:cellFrame.size scalingType:scaleStyle];

    switch (alignmentStyle) {
        default:
        case NSImageAlignLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignCenter:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yCenterInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTop:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottom:
            position.x = xCenterInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTopLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignTopRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yTopInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottomLeft:
            position.x = xLeftInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
        case NSImageAlignBottomRight:
            position.x = xRightInRect(imageSize, cellFrame);
            position.y = yBottomInRect(imageSize, cellFrame, is_flipped);
            break;
    }

    return [self centerScanRect:NSMakeRect(position.x, position.y, imageSize.width, imageSize.height)];
}

- (void)drawImage:(NSImage *)theImage atIndex:(NSUInteger)idx inRect:(NSRect)cellFrame operation:(NSUInteger)compositeType {

  // do nothing if cell's frame rect is zero
  if (NSIsEmptyRect(cellFrame)) return;

  NSString *alignmentString = [self getElementValueFor:@"imageAlignment" atIndex:idx onlyIfSet:NO] ;
  NSImageAlignment alignment = [IMAGEALIGNMENT_TYPES[alignmentString] unsignedIntValue] ;

  NSString *scalingString = [self getElementValueFor:@"imageScaling" atIndex:idx onlyIfSet:NO] ;
  NSImageScaling scaling = [IMAGESCALING_TYPES[scalingString] unsignedIntValue] ;

  NSNumber *alpha  ;
  if ([theImage isTemplate]) {
  // approximates NSCell's drawing of a template image since drawInRect bypasses Apple's template handling
      alpha = [self getElementValueFor:@"imageAlpha" atIndex:idx onlyIfSet:YES] ;
      if (!alpha) alpha = @(0.5) ;
  } else {
      alpha = [self getElementValueFor:@"imageAlpha" atIndex:idx] ;
  }

  // draw actual image
  NSRect rect = [self realRectFor:theImage inFrame:cellFrame withScaling:scaling withAlignment:alignment] ;

  NSGraphicsContext* gc = [NSGraphicsContext currentContext];
  [gc saveGraphicsState];
  [NSBezierPath clipRect:cellFrame] ;

  NSSize realImageSize = [theImage size] ;
  [theImage drawInRect:rect
              fromRect:NSMakeRect(0, 0, realImageSize.width, realImageSize.height)
             operation:compositeType
              fraction:[alpha doubleValue]
        respectFlipped:YES
                 hints:nil];

  [gc restoreGraphicsState];
}

@end

@implementation HSGifAnimator
-(instancetype)initWithImage:(NSImage *)image forCanvas:(HSCanvasView *)canvas {
    self = [super init] ;
    if (self) {
      _inCanvas                = canvas ;
      _isRunning               = NO ;

      NSBitmapImageRep *animatingRepresentation = nil ;
      for (NSBitmapImageRep *representation in [image representations]) {
          if ([representation isKindOfClass:[NSBitmapImageRep class]]) {
              NSNumber *maxFrames = [representation valueForProperty:NSImageFrameCount] ;
              if (maxFrames) {
                  animatingRepresentation = representation ;
                  break ;
              }
          }
      }
      // if _animatingRepresentation is nil, start and stop don't do anything, so this becomes a no-op
      _animatingRepresentation = animatingRepresentation ;
    }
    return self ;
}

-(void)startAnimating {
    NSBitmapImageRep *animatingRepresentation = _animatingRepresentation ;
    if (animatingRepresentation) {
        if (!_isRunning) {
            NSNumber *frameDuration  = [animatingRepresentation valueForProperty:NSImageCurrentFrameDuration] ;
            if (!frameDuration) frameDuration = @(0.1) ;
            [NSTimer scheduledTimerWithTimeInterval:[frameDuration doubleValue]
                                             target:self
                                           selector:@selector(animateFrame:)
                                           userInfo:nil
                                            repeats:NO] ;

            _isRunning = YES ;
        }
    } else {
        _isRunning = NO ;
    }
}

-(void)stopAnimating {
    if (_isRunning) {
        _isRunning = NO ;
    }
}

-(void)animateFrame:(__unused NSTimer *)timer {
    NSBitmapImageRep *animatingRepresentation = _animatingRepresentation ;
    HSCanvasView    *inCanvas                = _inCanvas ;

    if (animatingRepresentation && inCanvas) {
        NSNumber *maxFrames = [animatingRepresentation valueForProperty:NSImageFrameCount] ;
        NSNumber *curFrame  = [animatingRepresentation valueForProperty:NSImageCurrentFrame] ;
        NSInteger newFrame  = ([curFrame integerValue] + 1) % [maxFrames integerValue] ;
        [animatingRepresentation setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithInteger:newFrame]] ;
        inCanvas.needsDisplay = YES ;

        if (_isRunning) {
            _isRunning = NO ;
            [self startAnimating] ;
        }
    } else {
        _isRunning = NO ;
    }
}

@end
