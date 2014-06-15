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
