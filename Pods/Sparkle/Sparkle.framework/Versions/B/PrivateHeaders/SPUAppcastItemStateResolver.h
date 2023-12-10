//
//  SPUAppcastItemStateResolver.h
//  Sparkle
//
//  Created by Mayur Pawashe on 5/31/21.
//  Copyright © 2021 Sparkle Project. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Sparkle/SUExport.h>

NS_ASSUME_NONNULL_BEGIN

@class SUStandardVersionComparator, SPUAppcastItemState;
@protocol SUVersionComparison;

/**
 Private exposed class used to resolve Appcast Item properties that rely on external factors such as a host.
 This resolver is used for constructing appcast items.
 */
SU_EXPORT @interface SPUAppcastItemStateResolver : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithHostVersion:(NSString *)hostVersion applicationVersionComparator:(id<SUVersionComparison>)applicationVersionComparator standardVersionComparator:(SUStandardVersionComparator *)standardVersionComparator;

@end

NS_ASSUME_NONNULL_END
