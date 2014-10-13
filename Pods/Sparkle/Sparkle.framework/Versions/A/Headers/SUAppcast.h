//
//  SUAppcast.h
//  Sparkle
//
//  Created by Andy Matuschak on 3/12/06.
//  Copyright 2006 Andy Matuschak. All rights reserved.
//

#ifndef SUAPPCAST_H
#define SUAPPCAST_H

@protocol SUAppcastDelegate;

@class SUAppcastItem;
@interface SUAppcast : NSObject <NSURLDownloadDelegate>

@property (weak) id<SUAppcastDelegate> delegate;
@property (copy) NSString *userAgentString;

- (void)fetchAppcastFromURL:(NSURL *)url;

@property (readonly, copy) NSArray *items;
@end

@protocol SUAppcastDelegate <NSObject>
- (void)appcastDidFinishLoading:(SUAppcast *)appcast;
- (void)appcast:(SUAppcast *)appcast failedToLoadWithError:(NSError *)error;
@end

#endif
