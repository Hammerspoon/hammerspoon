#import "helpers.h"
#import "HydraLicense.h"

static HydraLicense* license;

static int license_enter(lua_State* L) {
    [license enter];
    return 0;
}

static int license_haslicense(lua_State* L) {
    lua_pushboolean(L, [license hasLicense]);
    return 1;
}

static int license_verify(lua_State* L) {
    NSString* pubkey = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];
    NSString* sig = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    NSString* email = [NSString stringWithUTF8String:luaL_checkstring(L, 3)];
    lua_pushboolean(L, hydra_verifylicense(pubkey, sig, email));
    return 1;
}

static luaL_Reg licenselib[] = {
    {"enter", license_enter},
    {"haslicense", license_haslicense},
    {"_verify", license_verify},
    {NULL, NULL}
};

int luaopen_hydra_license(lua_State* L) {
    license = [[HydraLicense alloc] init];
    [license initialCheck];
    
    luaL_newlib(L, licenselib);
    return 1;
}
