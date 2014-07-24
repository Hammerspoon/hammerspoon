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

static luaL_Reg licenselib[] = {
    {"enter", license_enter},
    {"haslicense", license_haslicense},
    {NULL, NULL}
};

int luaopen_hydra_license(lua_State* L) {
    license = [[HydraLicense alloc] init];
    [license initialCheck];
    
    luaL_newlib(L, licenselib);
    return 1;
}
