//- (CGRect) frameIncludingDockAndMenu {
//    NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
//    CGRect f = [self frame];
//    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
//    return f;
//}
//
//- (CGRect) frameWithoutDockOrMenu {
//    NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
//    CGRect f = [self visibleFrame];
//    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
//    return f;
//}
//
//- (NSScreen*) nextScreen {
//    NSArray* screens = [NSScreen screens];
//    NSUInteger idx = [screens indexOfObject:self];
//    
//    idx += 1;
//    if (idx == [screens count])
//        idx = 0;
//        
//        return [screens objectAtIndex:idx];
//}
//
//- (NSScreen*) previousScreen {
//    NSArray* screens = [NSScreen screens];
//    NSUInteger idx = [screens indexOfObject:self];
//    
//    idx -= 1;
//    if (idx == -1)
//        idx = [screens count] - 1;
//        
//        return [screens objectAtIndex:idx];
//}



//#import "lua/lauxlib.h"
//
//int misc_set_tint(lua_State* L) {
//    // args: NSArray *red, NSArray *green, NSArray *blue
//
//    CGGammaValue cred[red.count];
//    for (int i = 0; i < red.count; ++i) {
//        cred[i] = [[red objectAtIndex:i] floatValue];
//    }
//    CGGammaValue cgreen[green.count];
//    for (int i = 0; i < green.count; ++i) {
//        cgreen[i] = [[green objectAtIndex:i] floatValue];
//    }
//    CGGammaValue cblue[blue.count];
//    for (int i = 0; i < blue.count; ++i) {
//        cblue[i] = [[blue objectAtIndex:i] floatValue];
//    }
//    CGSetDisplayTransferByTable(CGMainDisplayID(), (int)sizeof(cred) / sizeof(cred[0]), cred, cgreen, cblue);
//
//    return 0;
//}
