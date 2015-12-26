//
//  chooser.h
//  Hammerspoon
//
//  Created by Chris Jones on 27/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooser.h"
#import "HSChooserCell.h"

#pragma mark - Module metadata

#define USERDATA_TAG "hs.chooser"

static int refTable = LUA_NOREF;

typedef struct _chooser_userdata_t {
    int selfRef;
    void *chooser;
} chooser_userdata_t;

#pragma mark - Lua API defines
static int userdata_gc(lua_State *L);