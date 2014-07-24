#import "helpers.h"
#import "HydraLicense.h"

static HydraLicense* license;

static int license_enter(lua_State* L) {
    [license enter];
    return 0;
}

static luaL_Reg licenselib[] = {
    {"enter", license_enter},
    {NULL, NULL}
};

int luaopen_hydra_license(lua_State* L) {
    license = [[HydraLicense alloc] init];
    [license initialCheck];
    
    luaL_newlib(L, licenselib);
    return 1;
}
