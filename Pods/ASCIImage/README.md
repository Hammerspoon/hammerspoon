# ASCIImage

[![CI Status](http://img.shields.io/travis/esttorhe/ASCIImage.svg?style=flat)](https://travis-ci.org/esttorhe/ASCIImage)
[![Version](https://img.shields.io/cocoapods/v/ASCIImage.svg?style=flat)](http://cocoapods.org/pods/ASCIImage)
[![License](https://img.shields.io/cocoapods/l/ASCIImage.svg?style=flat)](http://cocoapods.org/pods/ASCIImage)
[![Platform](https://img.shields.io/cocoapods/p/ASCIImage.svg?style=flat)](http://cocoapods.org/pods/ASCIImage)

**Create UIImage / NSImage instances from NSString, by combining ASCII art and Kindergarten skills.**

## Useful links

* ASCIImage reference site: [asciimage.org](http://asciimage.org)
* Original blog post presenting ASCIImage: [Replacing Photoshop with NSString](http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/)
* Slides from the presentation of ASCIImage at NSConference 7: [ASCCImage slides and editor](http://cocoamine.net/blog/2015/03/21/asciimage-slides-and-editor/)
* ASCIImage Super Studio: [source on Github](https://github.com/mz2/ASCIImage-Super-Studio)
* For ASCII art lovers: [MonoDraw](http://monodraw.helftone.com) (not affiliated with ASCIImage; just an awesome app that I like)

## FAQs

#### Why ASCIImage?

The [original blog post](http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/) explains the genesis of ASCIImage, but it might still be confusing why anybody would use it, and for what purpose. Its main strength is that it combines two things: (1) having the image directly in code, and (2) seeing the image. The code is the image, the image is the code. It really only works like this for simple images composed of a few lines and / or simple shapes. Anything more complicated defeats point (2), and might not even be feasible with ASCIImage purposedly-limited options.

#### Pixels or vectors?

While it was initially developed with bitmaps in mind, and while the ASCII representation looks like pixels, the connect-the-numbers approach makes it a vector-drawing tool, with forced pixel alignment. This can be confusing. Even I was confused without realizing: I did not use the word 'vector' once in my original blog post. Only when the first editor was developed (ASCIImage Super Studio) did I realize it could draw very large images with smooth curves, and output things I had never envisioned. That is because behind the scenes, shapes are first made into NSBezierPath. In the end, of course, everything on a screen ends up as pixels.

#### What's next?

The idea and initial implementation was mostly a one-day hack. But I did refine a few details over the year that followed, before finally making it public in March 2015. As a result of these tweaks, it is really filling out all my needs for what I use it for. I may add a few more options to the drawing "context" in the block-based API, in particular to exploit the vector aspect more, with scaling and smooting options. I am also curious to see what others do with it. But I think I want to really keep it simple and restricted to the original spirit: code and image in one place, with instant gratification. For more complex things, designers, real image editors and real formats should be used.

#### What apps are using ASCIImage?

Please let me know if you use ASCIImage in a shipping app, and I'll add it to the list here.

For now, I only know of [Findings](http://findingsapp.com) (disclaimer: I, the author of ASCIImage, makes a living from Findings).

#### Why not just use SVG?

Sigh.

## Documentation

### Installation

ASCIImage is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "ASCIImage"
```

#### Characters and Pixels

An image is defined by an array of strings, where each string represents a row. Here is an example:

    NSArray *asciiRepresentation =
    @[
    @"· · · 1 2 · · · · · ",
    @"· · · A # # · · · · ",
    @"· · · · # # # · · · ",
    @"· · · · · # # # · · ",
    @"· · · · · · 9 # 3 · ",
    @"· · · · · · 8 # 4 · ",
    @"· · · · · # # # · · ",
    @"· · · · # # # · · · ",
    @"· · · 7 # # · · · · ",
    @"· · · 6 5 · · · · · ",
    ];

In this documentation, I'll just represent it as follows:

    · · · 1 2 · · · · · 
    · · · A # # · · · · 
    · · · · # # # · · · 
    · · · · · # # # · · 
    · · · · · · 9 # 3 · 
    · · · · · · 8 # 4 · 
    · · · · · # # # · · 
    · · · · # # # · · · 
    · · · 7 # # · · · · 
    · · · 6 5 · · · · · 
  


Whitespace is ignored. The 2 representations below are thus equivalent. It should be clear why using extra whitespace is recommended: it really helps make the content appear at the right aspect ratio.

    · · · 1 2 · · · · ·          ···12·····
    · · · A # # · · · ·          ···A##····
    · · · · # # # · · ·          ····###···
    · · · · · # # # · ·          ·····###··
    · · · · · · 9 # 3 ·          ······9#3·
    · · · · · · 8 # 4 ·          ······8#4·
    · · · · · # # # · ·          ·····###··
    · · · · # # # · · ·          ····###···
    · · · 7 # # · · · ·          ···7##····
    · · · 6 5 · · · · ·          ···65·····

Each row should have the same number of non-whitespace character or else you get nothing but a mysterious console log.  These representations are invalid:

    ! ! I N V A L I D !             N O # G O O D ! 
    · ····1 2 · · · · ·               1 2           
    · · · A # # · · · ·               A # #         
    · · · · # # # · · ·                 # # #       
    · · · · · # # # · ·                   # # #     
    · · · · · · 9 # 3 ·                     9 # 3   
    · · · · · · 8 # 4 ·                     8 # 4   
    · · · · · # # # · ·                   # # #     
    · · · · # # # · · ·                 # # #       
    · · · 7 # # · · · ·               7 # #         
    · · · 6 5 · · · · ·               6 5           


#### Special Characters

While all non-whitespace characters count as part of the pixel grid, most characters are passive. Only the following characters are considered as part of shapes:

    1 2 3 4 5 6 7 8 9 A B C D E F G H I J K L M N O P
    Q R S T U V W X Y Z a b c d e f g h i j k l m n p
    q r s t u v w x y z

Note that the O (zero) and o (lowercase letter O) are ignored. The current implementation does not ignore the uppercase letter O. Any of those 3 things could be considered a bug, but that's just the way I thought it would be best. Maybe I'll regret it. Probably not.

All the other characters are ignored when it comes time to extract shapes from the grid of characters.

All the following representations are thus equivalent. The '#' signs in those examples are very useful as a guide for the eyes, and I use them all the time (@ works well too). But they can also be used for evil obfuscation! Bad!


    · 1 2 · · · · ·        · 1 2 · · · · ·         · 1 2 · · · · ·        # 1 2 # # # # # 
    · A # # · · · ·        · A @ @ · · · ·         · A · · · · · ·        # A # # # # # # 
    · · # # # · · ·        · · @ @ @ · · ·         · · · · · · · ·        # # # # # # # # 
    · · · # # # · ·        · · · @ @ @ · ·         · · · · · · · ·        # # # # # # # # 
    · · · · 9 # 3 ·        · · · · 9 @ 3 ·         · · · · 9 · 3 ·        # # # # 9 # 3 # 
    · · · · 8 # 4 ·        · · · · 8 @ 4 ·         · · · · 8 · 4 ·        # # # # 8 # 4 # 
    · · · # # # · ·        · · · @ @ @ · ·         · · · · · · · ·        # # # # # # # # 
    · · # # # · · ·        · · @ @ @ · · ·         · · · · · · · ·        # # # # # # # # 
    · 7 # # · · · ·        · 7 @ @ · · · ·         · 7 · · · · · ·        # 7 # # # # # # 
    · 6 5 · · · · ·        · 6 5 · · · · ·         · 6 5 · · · · ·        # 6 5 # # # # # 


#### Bezier Paths

Before being rendered into an NSImage, the ASCII grid is transformed into a series of NSBezierPath. The next sections describe the different types of Bezier paths that may be created.

#### Polygons

The simplest use of the above characters is to draw polygons using the famous 'connect-the-numbers' technique. Each polygon is defined by a series of sequential characters, and a new polygon is started as soon as you skip a character in the above list. So the first polygon could be defined by the series '123456', the next shape with '89ABCDEF', the next with 'HIJKLMNOP', etc. For polygons, each character can only be used once (or never). If you run out of characters, you are probably abusing ASCIImage!

Here is an example with 3 polygons, defined with the series [1,2,3,4,5,6,7,8,9,A], then [C,D,E] and finally [G,H,I,J,K,L]. Note that the characters B and F were skipped to separate the three polygons. The second example next to it is equivalent, but the last polygon uses the series [a,b,c,d,e,f] for no good reason (but also no bad reason).

    · · · · · · · · C · · E         · · · · · · · · C · · E 
    · · · 1 2 · · · · · · ·         · · · 1 2 · · · · · · · 
    · · · A · · · · · · · ·         · · · A · · · · · · · · 
    · · · · · · · · · · · D         · · · · · · · · · · · D 
    G · H · · · · · · · · ·         a · b · · · · · · · · · 
    · · · · · · 9 · 3 · · ·         · · · · · · 9 · 3 · · · 
    · · I J · · 8 · 4 · · ·         · · c d · · 8 · 4 · · · 
    L · · K · · · · · · · ·         f · · e · · · · · · · · 
    · · · · · · · · · · · ·         · · · · · · · · · · · · 
    · · · 7 · · · · · · · ·         · · · 7 · · · · · · · · 
    · · · 6 5 · · · · · · ·         · · · 6 5 · · · · · · · 
    · · · · · · · · · · · ·         · · · · · · · · · · · · 

#### Single points

When a polygon is composed of just 1 character, it is made into a square filling out the corresponding point. The following representation contains 5 separate points.

    · · 1 · · · · · · 5 · T 
    · · · · 3 · · · · · · · 
    · · · · · · · · · · 7 · 
    · · · · · · · · · · · · 

#### Lines

When a character is used exactly twice, the corresponding shape will be a line joining the two points (center to center, with square ends, which will fill the pixels exactly when using a 1-point width for drawing). Since such characters are used more than once, they cannot be part of a polygon, and there is no need to skip characters between a line and any other shape. Here is an example with 3 lines and a triangle. Note how we don't skip any character (but we could).

    · · 1 # # # # # # 1 6 · 
    · · · · · · · · · · # · 
    · · · · 2 · 3 · · · # · 
    · · · · · 4 · · · · # · 
    · · · · · · · · · · # · 
    · · 5 # # # # # # 5 6 · 


#### Ellipses

When a character is used three or more time, the corresponding shape will be an ellipse defined by the largest rectangles that include all the points. All the following representations will produce the same 11-point-diameter circle:

    · · · 1 1 1 1 1 · · ·      · · · · · 1 · · · · ·      · · · · · 1 · · · · ·    
    · · 1 · · · · · 1 · ·      · · · · · · · · · · ·      · · · · · · · · · · ·    
    · 1 · · · · · · · 1 ·      · · · · · · · · · · ·      · · · · · · · · · · ·    
    1 · · · · · · · · · 1      · · · · · · · · · · ·      · · · · · · · · · · ·    
    1 · · · · · · · · · 1      · · · · · · · · · · ·      · · · · · · · · · · ·    
    1 · · · · · · · · · 1      1 · · · · · · · · · 1      · · · · · · · · · · ·    
    1 · · · · · · · · · 1      · · · · · · · · · · ·      · · · · · · · · · · ·    
    1 · · · · · · · · · 1      · · · · · · · · · · ·      · · · · · · · · · · ·    
    · 1 · · · · · · · 1 ·      · · · · · · · · · · ·      · · · · · · · · · · ·    
    · · 1 · · · · · 1 · ·      · · · · · · · · · · ·      · · · · · · · · · · ·    
    · · · 1 1 1 1 1 · · ·      · · · · · 1 · · · · ·      1 · · · · · · · · · 1    


#### APIs

The word 'API' is a bit grandiose for ASCIImage. It is just an `NSImage` category, with 2 class methods.

The simplest method that I use 99% of the time:

    + (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep
                                         color:(PARColor *)color
                               shouldAntialias:(BOOL)shouldAntialias;

With this simple form, the single points, polygons and ellipses will be filled with the color, while lines will be 'stroked' with that same color. Simple.

The second method offers more advanced options that can be set on each "shape", using the `contextHandler` block. The mutable dictionary passed by the block can be modified using the keys listed in the constants below. The dictionary initially contains the `ASCIIContextShapeIndex` key to signal which shape the context will be applied to.

    + (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep
                                contextHandler:(void(^)(NSMutableDictionary *ctx))handler;

And here are the keys for the dictionary context:

    extern NSString * const ASCIIContextShapeIndex;
    extern NSString * const ASCIIContextFillColor;
    extern NSString * const ASCIIContextStrokeColor;
    extern NSString * const ASCIIContextLineWidth;
    extern NSString * const ASCIIContextShouldClose;
    extern NSString * const ASCIIContextShouldAntialias;

Note that some of these options are in fact applied to the Bezier paths (line width, should close), while others are applied to the actual graphic context. The antialiasing option can alter both. ASCIImage is doing a few things behind the scenes to keep the illusion going.

## Author

cparnot, charles.parnot@gmail.com

## License

ASCIImage is available under the MIT license. See the LICENSE file for more info.
