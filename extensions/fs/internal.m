/*
 ** LuaFileSystem
 ** Copyright Kepler Project 2003 (http://www.keplerproject.org/luafilesystem)
 **
 ** File system manipulation library.
 ** This library offers these functions:
 **   lfs.attributes (filepath [, attributename])
 **   lfs.chdir (path)
 **   lfs.currentDir ()
 **   lfs.dir (path)
 **   lfs.lock (fh, mode)
 **   lfs.lock_dir (path)
 **   lfs.mkdir (path)
 **   lfs.rmdir (path)
 **   lfs.setmode (filepath, mode)
 **   lfs.symlinkAttributes (filepath [, attributename]) -- thanks to Sam Roberts
 **   lfs.touch (filepath [, atime [, mtime]])
 **   lfs.unlock (fh)
 **
 ** $Id: lfs.c,v 1.61 2009/07/04 02:10:16 mascarenhas Exp $
 */

@import Cocoa;
#include <LuaSkin/LuaSkin.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/types.h>
#include <utime.h>
#include "lfs.h"

// #define LFS_VERSION "1.8.0"

#include <sys/param.h>
#define LFS_MAXPATHLEN MAXPATHLEN

#define DIR_METATABLE "directory metatable"
typedef struct dir_data {
    int  closed;
    DIR *dir;
} dir_data;

#define LOCK_METATABLE "lock metatable"
#define STAT_STRUCT struct stat
#define STAT_FUNC stat
#define LSTAT_FUNC lstat

/*
 ** Utility functions
 */

NSURL *path_to_nsurl(NSString *path) {
    return [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];
}

const char *path_at_index(lua_State *L, int i) {
    NSString *path = [[LuaSkin sharedWithState:L] toNSObjectAtIndex:i];
    return [[path_to_nsurl(path) path] UTF8String];
}

NSArray *tags_from_lua_stack(lua_State *L) {
    NSMutableSet *tags = [[NSMutableSet alloc] init];

    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        if (lua_type(L, -1) == LUA_TSTRING) {
            NSString *tag = [[LuaSkin sharedWithState:L] toNSObjectAtIndex:-1];
            [tags addObject:tag];
        }
        lua_pop(L, 1);
    }
    return [tags allObjects];
}

NSArray *tags_from_file(lua_State *L, NSString *filePath) {
    NSURL *url = path_to_nsurl(filePath);
    NSArray *tags;
    NSError *error;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (![url getResourceValue:&tags forKey:NSURLTagNamesKey error:&error]) {
#pragma clang diagnostic pop
//         [[LuaSkin sharedWithState:L] logError:[NSString stringWithFormat:@"hs.fs tags_from_file() Unable to get tags for %@: %@", url, [error localizedDescription]]];
//         return nil;
        luaL_error(L, error.localizedDescription.UTF8String) ;
    }
    return tags;
}

BOOL tags_to_file(lua_State *L, NSString *filePath, NSArray *tags) {
    NSURL *url = path_to_nsurl(filePath);
    NSError *error;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
    if (![url setResourceValue:tags forKey:NSURLTagNamesKey error:&error]) {
#pragma clang diagnostic pop
//         [[LuaSkin sharedWithState:L] logError:[NSString stringWithFormat:@"hs.fs tags_to_file() Unable to set tags for %@: %@", url, [error localizedDescription]]];
//         return false;
        luaL_error(L, error.localizedDescription.UTF8String) ;
    }
    return true;
}

static int pusherror(lua_State * L, const char *info) {
    lua_pushnil(L);
    if (info == NULL)
        lua_pushstring(L, strerror(errno));
    else
        lua_pushfstring(L, "%s: %s", info, strerror(errno));
//     lua_pushinteger(L, errno);
//     return 3;
    return 2 ;
}


/*
 ** This function changes the working (current) directory
 */
/// hs.fs.chdir(path) -> true or (nil,error)
/// Function
/// Changes the current working directory to the given path.
///
/// Parameters:
///  * path - A string containing the path to change working directory to
///
/// Returns:
///  * If successful, returns true, otherwise returns nil and an error string
static int change_dir (lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TBREAK];
    const char *path = path_at_index(L, 1);

    if (chdir(path)) {
        lua_pushnil (L);
        lua_pushfstring (L,"Unable to change working directory to '%s'\n%s\n", path, strerror(errno));
        return 2;
    } else {
        lua_pushboolean (L, 1);
        return 1;
    }
}

/*
 ** This function returns the current directory
 ** If unable to get the current directory, it returns nil
 **  and a string describing the error
 */
/// hs.fs.currentDir() -> string or (nil,error)
/// Function
/// Gets the current working directory
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the current working directory, or if an error occured, nil and an error string
static int get_dir(lua_State * L) {
    char *path = NULL;
    /* Passing (NULL, 0) is not guaranteed to work. Use a temp buffer and size instead. */
    size_t size = LFS_MAXPATHLEN; /* initial buffer size */
    int result;
    while (1) {
        char *path2 = realloc(path, size);
        if (!path2) {               /* failed to allocate */
            result = pusherror(L, "get_dir realloc() failed");
            break;
        }
        path = path2;
        if (getcwd(path, size) != NULL) {
            /* success, push the path to the Lua stack */
            lua_pushstring(L, path);
            result = 1;
            break;
        }
        if (errno != ERANGE) {      /* unexpected error */
            result = pusherror(L, "get_dir getcwd() failed");
            break;
        }
        /* ERANGE = insufficient buffer capacity, double size and retry */
        size *= 2;
    }
    free(path);
    return result;
}

/*
 ** Check if the given element on the stack is a file and returns it.
 */
static FILE *check_file(lua_State * L, int idx, const char *funcname) {
    luaL_Stream *fh = (luaL_Stream *) luaL_checkudata(L, idx, "FILE*");
    if (fh->closef == 0 || fh->f == NULL) {
        luaL_error(L, "%s: closed file", funcname);
        return 0;
    } else
        return fh->f;
}


/*
 **
 */
/// hs.fs.lock(filehandle, mode[, start[, length]]) -> true or (nil,error)
/// Function
/// Locks a file, or part of it
///
/// Parameters:
///  * filehandle - An open file
///  * mode - A string containing either "r" for a shared read lock, or "w" for an exclusive write lock
///  * start - An optional number containing an offset into the file to start the lock at. Defaults to 0
///  * length - An optional number containing the length of the file to lock. Defaults to the full size of the file
///
/// Returns:
///  * True if the lock was obtained successfully, otherwise nil and an error string
static int _file_lock (lua_State *L, FILE *fh, const char *mode, const long start, long len, const char *funcname) {
    int code;
    struct flock f;
    switch (*mode) {
        case 'w': f.l_type = F_WRLCK; break;
        case 'r': f.l_type = F_RDLCK; break;
        case 'u': f.l_type = F_UNLCK; break;
        default : return luaL_error (L, "%s: invalid mode", funcname);
    }
    f.l_whence = SEEK_SET;
    f.l_start = (off_t)start;
    f.l_len = (off_t)len;
    code = fcntl (fileno(fh), F_SETLK, &f);
    return (code != -1);
}

typedef struct lfs_Lock {
    char *ln;
} lfs_Lock;

/// hs.fs.lockDir(path, [seconds_stale]) -> lock or (nil,error)
/// Function
/// Locks a directory
///
/// Parameters:
///  * path - A string containing the path to a directory
///  * seconds_stale - An optional number containing an age (in seconds) beyond which to consider an existing lock as stale. Defaults to INT_MAX (which is, broadly speaking, equivalent to "never")
///
/// Returns:
///  * If successful, a lock object, otherwise nil and an error string
///
/// Notes:
///  * This is not a low level OS feature, the lock is actually a file created in the path, called `lockfile.lfs`, so the directory must be writable for this function to succeed
///  * The returned lock object can be freed with ```lock:free()```
///  * If the lock already exists and is not stale, the error string returned will be "File exists"
static int lfs_lock_dir(lua_State *L) {
    lfs_Lock *lock;
    size_t pathl;
    char *ln;
    const char *lockfile = "/lockfile.lfs";
    const char *path = luaL_checklstring(L, 1, &pathl);
    lock = (lfs_Lock*)lua_newuserdata(L, sizeof(lfs_Lock));
    ln = (char*)malloc(pathl + strlen(lockfile) + 1);
    if(!ln) {
        lua_pushnil(L); lua_pushstring(L, strerror(errno)); return 2;
    }
    strcpy(ln, path); strcat(ln, lockfile);
    if(symlink("lock", ln) == -1) {
        free(ln); lua_pushnil(L);
        lua_pushstring(L, strerror(errno)); return 2;
    }
    lock->ln = ln;
    luaL_getmetatable (L, LOCK_METATABLE);
    lua_setmetatable (L, -2);
    return 1;
}
static int lfs_unlock_dir(lua_State *L) {
    lfs_Lock *lock = (lfs_Lock *)luaL_checkudata(L, 1, LOCK_METATABLE);
    if(lock->ln) {
        unlink(lock->ln);
        free(lock->ln);
        lock->ln = NULL;
    }
    return 0;
}

/*
 ** Locks a file.
 ** @param #1 File handle.
 ** @param #2 String with lock mode ('w'rite, 'r'ead).
 ** @param #3 Number with start position (optional).
 ** @param #4 Number with length (optional).
 */
static int file_lock (lua_State *L) {
    FILE *fh = check_file (L, 1, "lock");
    const char *mode = luaL_checkstring (L, 2);
    const long start = (long) luaL_optinteger(L, 3, 0);
    long len = (long) luaL_optinteger(L, 4, 0);
    if (_file_lock (L, fh, mode, start, len, "lock")) {
        lua_pushboolean (L, 1);
        return 1;
    } else {
        lua_pushnil (L);
        lua_pushfstring (L, "%s", strerror(errno));
        return 2;
    }
}

/*
 ** Unlocks a file.
 ** @param #1 File handle.
 ** @param #2 Number with start position (optional).
 ** @param #3 Number with length (optional).
 */
/// hs.fs.unlock(filehandle[, start[, length]]) -> true or (nil,error)
/// Function
/// Unlocks a file or a part of it.
///
/// Parameters:
///  * filehandle - An open file
///  * start - An optional number containing an offset from the start of the file, to unlock. Defaults to 0
///  * length - An optional number containing the length of file to unlock. Defaults to the full size of the file
///
/// Returns:
///  * True if the unlock succeeded, otherwise nil and an error string
static int file_unlock (lua_State *L) {
    FILE *fh = check_file (L, 1, "unlock");
    const long start = (long) luaL_optinteger(L, 2, 0);
    long len = (long) luaL_optinteger(L, 3, 0);
    if (_file_lock (L, fh, "u", start, len, "unlock")) {
        lua_pushboolean (L, 1);
        return 1;
    } else {
        lua_pushnil (L);
        lua_pushfstring (L, "%s", strerror(errno));
        return 2;
    }
}

/*
 ** Creates a link.
 ** @param #1 Object to link to.
 ** @param #2 Name of link.
 ** @param #3 True if link is symbolic (optional).
 */
/// hs.fs.link(old, new[, symlink]) -> true or (nil,error)
/// Function
/// Creates a link
///
/// Parameters:
///  * old - A string containing a path to a filesystem object to link from
///  * new - A string containing a path to create the link at
///  * symlink - An optional boolean, true to create a symlink, false to create a hard link. Defaults to false
///
/// Returns:
///  * True if the link was created, otherwise nil and an error string
static int make_link(lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TSTRING, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];
    const char *oldpath = path_at_index(L, 1);
    const char *newpath = path_at_index(L, 2);
    BOOL error;

    if (lua_toboolean (L, 3)) {
        error = (symlink(oldpath, newpath) != 0);
    } else {
        error = (link(oldpath, newpath) != 0);
    }

    if (error) {
        lua_pushnil(L);
        lua_pushstring(L, strerror(errno));
        return 2;
    } else lua_pushboolean(L, true);

    return 1;
}

/*
 ** Creates a directory.
 ** @param #1 Directory path.
 */
/// hs.fs.mkdir(dirname) -> true or (nil,error)
/// Function
/// Creates a new directory
///
/// Parameters:
///  * dirname - A string containing the path of a directory to create
///
/// Returns:
///  * True if the directory was created, otherwise nil and an error string
static int make_dir (lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TBREAK];
    const char *path = path_at_index(L, 1);

    int fail =  mkdir (path, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP |
                       S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH );
    if (fail) {
        lua_pushnil (L);
        lua_pushfstring (L, "%s", strerror(errno));
        return 2;
    }
    lua_pushboolean (L, 1);
    return 1;
}


/*
 ** Removes a directory.
 ** @param #1 Directory path.
 */
/// hs.fs.rmdir(dirname) -> true or (nil,error)
/// Function
/// Removes an existing directory
///
/// Parameters:
///  * dirname - A string containing the path to a directory to remove
///
/// Returns:
///  * True if the directory was removed, otherwise nil and an error string
static int remove_dir (lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TBREAK];
    const char *path = path_at_index(L, 1);
    int fail;

    fail = rmdir (path);

    if (fail) {
        lua_pushnil (L);
        lua_pushfstring (L, "%s", strerror(errno));
        return 2;
    }
    lua_pushboolean (L, 1);
    return 1;
}


/*
 ** Directory iterator
 */
static int dir_iter (lua_State *L) {
    struct dirent *entry;
    dir_data *d = (dir_data *)luaL_checkudata (L, 1, DIR_METATABLE);
    luaL_argcheck (L, d->closed == 0, 1, "closed directory");

    if ((entry = readdir (d->dir)) != NULL) {
        lua_pushstring (L, entry->d_name);
        return 1;
    } else {
        /* no more entries => close directory */
        closedir (d->dir);
        d->closed = 1;
        return 0;
    }
}


/*
 ** Closes directory iterators
 */
static int dir_close (lua_State *L) {
    dir_data *d = (dir_data *)lua_touserdata (L, 1);
    if (!d->closed && d->dir) {
        closedir (d->dir);
    }
    d->closed = 1;
    return 0;
}


/*
 ** Factory of directory iterators
 */
/// hs.fs.dir(path) -> iter_fn, dir_obj, nil, dir_obj
/// Function
/// Creates an iterator for walking a filesystem path
///
/// Parameters:
///  * path - A string containing a directory to iterate
///
/// Returns:
///  * An iterator function
///  * A data object to pass to the iterator function or an error message as a string
///  * `nil` as the initial argument for the iterator (unused and unnecessary in this case, but conforms to Lua spec for iterators). Ignore this value if you are not using this function with `for` (see Notes).
///  * A second data object used by `for` to close the directory object immediately when the loop terminates. Ignore this value if you are not using this function with `for` (see Notes).
///
/// Notes:
///  * Unlike most functions in this module, `hs.fs.dir` will throw a Lua error if the supplied path cannot be iterated.
///
///  * The simplest way to use this function is with a `for` loop. When used in this manner, the `for` loop itself will take care of closing the directory stream for us, even if we break out of the loop early.
///    ```
///       for file in hs.fs.dir("/Users/Guest/Documents") do
///           print(file)
///       end
///    ```
///
///  * It is also possible to use the dir_obj directly if you wish:
///    ```
///       local iterFn, dirObj = hs.fs.dir("/Users/Guest/Documents")
///       local file = dirObj:next() -- get the first file in the directory
///       while (file) do
///           print(file)
///           file = dirObj:next() -- get the next file in the directory
///       end
///       dirObj:close() -- necessary to make sure that the directory stream is closed
///    ```
static int dir_iter_factory (lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TBREAK];
    const char *path = path_at_index(L, 1);
    dir_data *d;
    lua_pushcfunction (L, dir_iter);
    d = (dir_data *) lua_newuserdata (L, sizeof(dir_data));
    luaL_getmetatable (L, DIR_METATABLE);
    lua_setmetatable (L, -2);
    d->closed = 0;
    d->dir = opendir (path);
    if (d->dir == NULL) {
        return luaL_error(L, "cannot open %s: %s", path, strerror (errno));
//         lua_pushnil(L);
//         lua_pushfstring(L, "cannot open %s: %s", path, strerror (errno));
//         return 2;
    }

    // Lua 5.4: use __close to close dir if you break the iterator
    // SOURCE: https://github.com/keplerproject/luafilesystem/commit/842505b6a33d0b0e2445568ea42f2adbf3c4eb77
        lua_pushnil(L);
        lua_pushvalue(L, -2); // forces "to-be-closed" when used with `for`
        return 4;
}


/*
 ** Creates directory metatable.
 */
static int dir_create_meta (lua_State *L) {
    luaL_newmetatable (L, DIR_METATABLE);

    /* Method table */
    lua_newtable(L);
    lua_pushcfunction (L, dir_iter);
    lua_setfield(L, -2, "next");
    lua_pushcfunction (L, dir_close);
    lua_setfield(L, -2, "close");

    /* Metamethods */
    lua_setfield(L, -2, "__index");
    lua_pushcfunction (L, dir_close);
    lua_setfield (L, -2, "__gc");

    lua_pushcfunction(L, dir_close);
    lua_setfield(L, -2, "__close");
    return 1;
}


/*
 ** Creates lock metatable.
 */
static int lock_create_meta (lua_State *L) {
    luaL_newmetatable (L, LOCK_METATABLE);

    /* Method table */
    lua_newtable(L);
    lua_pushcfunction(L, lfs_unlock_dir);
    lua_setfield(L, -2, "free");

    /* Metamethods */
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, lfs_unlock_dir);
    lua_setfield(L, -2, "__gc");
    return 1;
}

/*
 ** Convert the inode protection mode to a string.
 */
static const char *mode2string (mode_t mode) {
    if ( S_ISREG(mode) )
        return "file";
    else if ( S_ISDIR(mode) )
        return "directory";
    else if ( S_ISLNK(mode) )
        return "link";
    else if ( S_ISSOCK(mode) )
        return "socket";
    else if ( S_ISFIFO(mode) )
        return "named pipe";
    else if ( S_ISCHR(mode) )
        return "char device";
    else if ( S_ISBLK(mode) )
        return "block device";
    else
        return "other";
}


/*
 ** Set access time and modification values for file
 */
/// hs.fs.touch(filepath [, atime [, mtime]]) -> true or (nil,error)
/// Function
/// Updates the access and modification times of a file
///
/// Parameters:
///  * filepath - A string containing the path of a file to touch
///  * atime - An optional number containing the new access time of the file to set (as seconds since the Epoch). Defaults to now
///  * mtime - An optional number containing the new modification time of the file to set (as seconds since the Epoch). Defaults to the value of atime
///
/// Returns:
///  * True if the operation was successful, otherwise nil and an error string
static int file_utime (lua_State *L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TNUMBER|LS_TOPTIONAL, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];
    const char *file = path_at_index(L, 1);
    struct utimbuf utb, *buf;

    if (lua_gettop (L) == 1) /* set to current date/time */
        buf = NULL;
    else {
        utb.actime = (time_t) luaL_optinteger (L, 2, 0);
        utb.modtime = (time_t) luaL_optinteger (L, 3, utb.actime);
        buf = &utb;
    }
    if (utime (file, buf)) {
        lua_pushnil (L);
        lua_pushfstring (L, "%s", strerror (errno));
        return 2;
    }
    lua_pushboolean (L, 1);
    return 1;
}


/* inode protection mode */
static void push_st_mode (lua_State *L, STAT_STRUCT *info) {
    lua_pushstring (L, mode2string (info->st_mode));
}
/* device inode resides on */
static void push_st_dev (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_dev);
}
/* inode's number */
static void push_st_ino (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_ino);
}
/* number of hard links to the file */
static void push_st_nlink (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_nlink);
}
/* user-id of owner */
static void push_st_uid (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_uid);
}
/* group-id of owner */
static void push_st_gid (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_gid);
}
/* device type, for special file inode */
static void push_st_rdev (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_rdev);
}
/* time of last access */
static void push_st_atime (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_atime);
}
/* time of last data modification */
static void push_st_mtime (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_mtime);
}
/* time of last file status change */
static void push_st_ctime (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_ctime);
}
/* time of file creation */
static void push_st_birthtime (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_birthtime);
}
/* file size, in bytes */
static void push_st_size (lua_State *L, STAT_STRUCT *info) {
    lua_pushinteger (L, (lua_Integer)info->st_size);
}
/* blocks allocated for file */
static void push_st_blocks(lua_State * L, STAT_STRUCT * info) {
  lua_pushinteger(L, (lua_Integer) info->st_blocks);
}
/* optimal file system I/O blocksize */
static void push_st_blksize(lua_State * L, STAT_STRUCT * info) {
  lua_pushinteger(L, (lua_Integer) info->st_blksize);
}

/*
 ** Convert the inode protection mode to a permission list.
 */
static const char *perm2string (mode_t mode) {
    static char perms[10] = "---------";
    int i;
    for (i=0;i<9;i++) perms[i]='-';
    if (mode & S_IRUSR) perms[0] = 'r';
    if (mode & S_IWUSR) perms[1] = 'w';
    if (mode & S_IXUSR) perms[2] = 'x';
    if (mode & S_IRGRP) perms[3] = 'r';
    if (mode & S_IWGRP) perms[4] = 'w';
    if (mode & S_IXGRP) perms[5] = 'x';
    if (mode & S_IROTH) perms[6] = 'r';
    if (mode & S_IWOTH) perms[7] = 'w';
    if (mode & S_IXOTH) perms[8] = 'x';
    return perms;
}

/* permssions string */
static void push_st_perm (lua_State *L, STAT_STRUCT *info) {
    lua_pushstring (L, perm2string (info->st_mode));
}

typedef void (*_push_function) (lua_State *L, STAT_STRUCT *info);

typedef struct _stat_members {
    const char *name;
    _push_function push;
} stat_members;

static stat_members members[] = {
    { "mode",         push_st_mode },
    { "dev",          push_st_dev },
    { "ino",          push_st_ino },
    { "nlink",        push_st_nlink },
    { "uid",          push_st_uid },
    { "gid",          push_st_gid },
    { "rdev",         push_st_rdev },
    { "access",       push_st_atime },
    { "modification", push_st_mtime },
    { "change",       push_st_ctime },
    { "creation",     push_st_birthtime },
    { "size",         push_st_size },
    { "permissions",  push_st_perm },
    { "blocks",       push_st_blocks },
    { "blksize",      push_st_blksize },
    { NULL, NULL }
};

/*
 ** Get file or symbolic link information
 */
/// hs.fs.attributes(filepath [, aName]) -> table or string or nil,error
/// Function
/// Gets the attributes of a file
///
/// Parameters:
///  * filepath - A string containing the path of a file to inspect
///  * aName - An optional attribute name. If this value is specified, only the attribute requested, is returned
///
/// Returns:
///  * A table with the file attributes corresponding to filepath (or nil followed by an error message in case of error). If the second optional argument is given, then a string is returned with the value of the named attribute. attribute mode is a string, all the others are numbers, and the time related attributes use the same time reference of os.time:
///   * dev - A number containing the device the file resides on
///   * ino - A number containing the inode of the file
///   * mode - A string containing the type of the file (possible values are: file, directory, link, socket, named pipe, char device, block device or other)
///   * nlink - A number containing a count of hard links to the file
///   * uid - A number containing the user-id of owner
///   * gid - A number containing the group-id of owner
///   * rdev - A number containing the type of device, for files that are char/block devices
///   * access - A number containing the time of last access modification (as seconds since the UNIX epoch)
///   * change - A number containing the time of last file status change (as seconds since the UNIX epoch)
///   * modification - A number containing the time of the last file contents change (as seconds since the UNIX epoch)
///   * permissions - A 9 character string specifying the user access permissions for the file. The first three characters represent Read/Write/Execute permissions for the file owner. The first character will be "r" if the user has read permissions, "-" if they do not; the second will be "w" if they have write permissions, "-" if they do not; the third will be "x" if they have execute permissions, "-" if they do not. The second group of three characters follow the same convention, but refer to whether or not the file's group have Read/Write/Execute permissions, and the final three characters follow the same convention, but apply to other system users not covered by the Owner or Group fields.
///   * creation - A number containing the time the file was created (as seconds since the UNIX epoch)
///   * size - A number containing the file size, in bytes
///   * blocks - A number containing the number of blocks allocated for file
///   * blksize - A number containing the optimal file system I/O blocksize
///
/// Notes:
///  * This function uses `stat()` internally thus if the given filepath is a symbolic link, it is followed (if it points to another link the chain is followed recursively) and the information is about the file it refers to. To obtain information about the link itself, see function `hs.fs.symlinkAttributes()`
static int _file_info_ (lua_State *L, int (*st)(const char*, STAT_STRUCT*)) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TSTRING, LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];
    const char *file = path_at_index(L, 1);
    STAT_STRUCT info;
    int i;

    if (st(file, &info)) {
        lua_pushnil (L);
        lua_pushfstring(L, "cannot obtain information from file '%s': %s", file, strerror(errno));
        return 2;
    }
    if (lua_isstring (L, 2)) {
        const char *member = lua_tostring (L, 2);
        for (i = 0; members[i].name; i++) {
            if (strcmp(members[i].name, member) == 0) {
                /* push member value and return */
                members[i].push(L, &info);
                return 1;
            }
        }
        /* member not found */
        lua_pushnil (L);
        lua_pushfstring(L, "invalid attribute name '%s'", member);
        return 2;
    }
    /* creates a table if none is given, removes extra arguments */
    lua_settop(L, 2);
    if (!lua_istable (L, 2)) {
        lua_newtable (L);
    }
    /* stores all members in table on top of the stack */
    for (i = 0; members[i].name; i++) {
        lua_pushstring (L, members[i].name);
        members[i].push (L, &info);
        lua_rawset (L, -3);
    }
    return 1;
}


/*
 ** Get file information using stat.
 */
static int file_info (lua_State *L) {
    return _file_info_ (L, STAT_FUNC);
}


/*
 ** Get symbolic link information using lstat.
 */
static int link_info (lua_State *L) {
    return _file_info_ (L, LSTAT_FUNC);
}

/// hs.fs.tagsGet(filepath) -> table or nil
/// Function
/// Gets the Finder tags of a file
///
/// Parameters:
///  * filepath - A string containing the path of a file
///
/// Returns:
///  * A table containing the list of the file's tags, or nil if the file has no tags assigned; throws a lua error if an error accessing the file occurs
static int tagsGet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];

    NSArray *tags = tags_from_file(L, path);
    if (!tags) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);

    int i = 1;
    for (NSString *tag in tags) {
        lua_pushinteger(L, i++);
        lua_pushstring(L, [tag UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.fs.tagsAdd(filepath, tags)
/// Function
/// Adds one or more tags to the Finder tags of a file
///
/// Parameters:
///  * filepath - A string containing the path of a file
///  * tags - A table containing one or more strings, each containing a tag name
///
/// Returns:
///  * true if the tags were updated; throws a lua error if an error occurs updating the tags
static int tagsAdd(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];

    NSMutableSet *oldTags = [NSMutableSet setWithArray:tags_from_file(L, path)];
    NSMutableSet *newTags = [NSMutableSet setWithArray:tags_from_lua_stack(L)];
    [newTags unionSet:oldTags];
    lua_pushboolean(L, tags_to_file(L, path, [newTags allObjects]));

    return 1;
}

/// hs.fs.tagsSet(filepath, tags)
/// Function
/// Sets the Finder tags of a file, removing any that are already set
///
/// Parameters:
///  * filepath - A string containing the path of a file
///  * tags - A table containing zero or more strings, each containing a tag name
///
/// Returns:
///  * true if the tags were set; throws a lua error if an error occurs setting the new tags
static int tagsSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];

    NSArray *tags = tags_from_lua_stack(L);
    lua_pushboolean(L, tags_to_file(L, path, tags));

    return 1;
}

/// hs.fs.tagsRemove(filepath, tags)
/// Function
/// Removes Finder tags from a file
///
/// Parameters:
///  * filepath - A string containing the path of a file
///  * tags - A table containing one or more strings, each containing a tag name
///
/// Returns:
///  * true if the tags were updated; throws a lua error if an error occurs updating the tags
static int tagsRemove(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];
    NSMutableSet *removeTags = [NSMutableSet setWithArray:tags_from_lua_stack(L)];

    NSMutableSet *tags = [NSMutableSet setWithArray:tags_from_file(L, path)];
    [tags minusSet:removeTags];
    lua_pushboolean(L, tags_to_file(L, path, [tags allObjects]));

    return 1;
}

/// hs.fs.temporaryDirectory() -> string
/// Function
/// Returns the path of the temporary directory for the current user.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The path to the system designated temporary directory for the current user.
static int hs_temporaryDirectory(lua_State *L) {
    lua_pushstring(L, [NSTemporaryDirectory() UTF8String]) ;
    return 1 ;
}

/// hs.fs.fileUTI(path) -> string or nil
/// Function
/// Returns the Uniform Type Identifier for the file location specified.
///
/// Parameters:
///  * path - the path to the file to return the UTI for.
///
/// Returns:
///  * a string containing the Uniform Type Identifier for the file location specified or nil if an error occured
static int hs_fileuti(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *path = [NSString stringWithUTF8String:path_at_index(L, 1)];

    NSError *error ;
    NSString *type = [[NSWorkspace sharedWorkspace] typeOfFile:path error:&error] ;
    if (error) {
        lua_pushnil(L);
        [skin logError:[error localizedDescription]];
    }
    [skin pushNSObject:type] ;
    return 1 ;
}

/// hs.fs.fileUTIalternate(fileUTI, type) -> string
/// Function
/// Returns the fileUTI's equivalent form in an alternate type specification format.
///
/// Parameters:
///  * a string containing a file UTI, such as one returned by `hs.fs.fileUTI`.
///  * a string specifying the alternate format for the UTI.  This string may be one of the following:
///     * `extension`  - as a file extension, commonly used for platform independant file sharing when file metadata can't be guaranteed to be cross-platform compatible.  Generally considered unreliable when other file type identification methods are available.
///    * `mime`       - as a mime-type, commonly used by Internet applications like web browsers and email applications.
///    * `pasteboard` - as an NSPasteboard type (see `hs.pasteboard`).
///    * `ostype`     - four character file type, most common pre OS X, but still used in some legacy APIs.
///
/// Returns:
///  * the file UTI in the alternate format or nil if the UTI does not have an alternate of the specified type.
static int hs_fileUTIalternate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
    NSString *fileUTI = [skin toNSObjectAtIndex:1] ;
    NSString *format  = [skin toNSObjectAtIndex:2] ;

    NSString *convertTo ;
    if ([format isEqualToString:@"extension"]) {
        convertTo = (__bridge NSString *)kUTTagClassFilenameExtension ;
    } else if ([format isEqualToString:@"mime"]) {
        convertTo = (__bridge NSString *)kUTTagClassMIMEType ;
    } else if ([format isEqualToString:@"pasteboard"]) {
        convertTo = (__bridge NSString *)kUTTagClassNSPboardType ;
    } else if ([format isEqualToString:@"ostype"]) {
        convertTo = (__bridge NSString *)kUTTagClassOSType ;
    } else {
        return luaL_error(L, "invalid alternate type %s specified", [format UTF8String]) ;
    }

    [skin pushNSObject:(__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)fileUTI, (__bridge CFStringRef)convertTo)] ;
    return 1 ;
}

/// hs.fs.pathToAbsolute(filepath) -> string
/// Function
/// Gets the absolute path of a given path
///
/// Parameters:
///  * filepath - Any kind of file or directory path, be it relative or not
///
/// Returns:
///  * A string containing the absolute path of `filepath` (i.e. one that doesn't include `.`, `..` or symlinks)
///  * Note that symlinks will be resolved to their target file
static int hs_pathToAbsolute(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *filePath = [skin toNSObjectAtIndex:1];
    char *absolutePath = realpath([filePath stringByExpandingTildeInPath].UTF8String, NULL);

    if (!absolutePath) {
        lua_pushnil(L);
        return 1;
    }

    lua_pushstring(L, absolutePath);
    free(absolutePath);
    return 1;
}

/// hs.fs.displayName(filepath) -> string
/// Function
/// Returns the display name of the file or directory at a specified path.
///
/// Parameters:
///  * filepath - The path to the file or directory
///
/// Returns:
///  * a string containing the display name of the file or directory at a specified path; returns nil if no file with the specified path exists.
static int fs_displayName(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString *filePath = [skin toNSObjectAtIndex:1];
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath.stringByExpandingTildeInPath]) {
        [skin pushNSObject:[[NSFileManager defaultManager] displayNameAtPath:filePath.stringByExpandingTildeInPath]] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.fs.pathToBookmark(path) -> string | nil
/// Function
/// Returns the path as binary encoded bookmark data.
///
/// Parameters:
///  * path - The path to encode
///
/// Returns:
///  * Bookmark data in a binary encoded string or `nil` if path is invalid.
static int fs_pathToBookmark(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *filePath = [skin toNSObjectAtIndex:1];
    char *absolutePath = realpath([filePath stringByExpandingTildeInPath].UTF8String, NULL);

    if (!absolutePath) {
        lua_pushnil(L);
        return 1;
    }

    NSData *bookmarkData = [[NSURL fileURLWithPath:filePath]
                    bookmarkDataWithOptions:0
                    includingResourceValuesForKeys:nil
                    relativeToURL:nil
                    error:nil];
    [skin pushNSObject:bookmarkData] ;
    free(absolutePath);
    return 1 ;
}

/// hs.fs.pathFromBookmark(data) -> string | nil, string
/// Function
/// Gets the file path from a binary encoded bookmark.
///
/// Parameters:
///  * data - The binary encoded Bookmark.
///
/// Returns:
///  * A string containing the path to the Bookmark URL or `nil` if an error occurs.
///  * An error message if an error occurs.
///
/// Notes:
///  * A bookmark provides a persistent reference to a file-system resource.
///    When you resolve a bookmark, you obtain a URL to the resource’s current location.
///    A bookmark’s association with a file-system resource (typically a file or folder)
///    usually continues to work if the user moves or renames the resource, or if the
///    user relaunches your app or restarts the system.
///  * No volumes are mounted during the resolution of the bookmark data.
static int fs_pathFromBookmark(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    const char *data = lua_tostring(L, 1);
    NSUInteger dataLength = lua_rawlen(L, 1);
    NSData *bookmarkData = [NSData dataWithBytes:data length:dataLength];

    NSError *error = nil;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmarkData
                                           options:NSURLBookmarkResolutionWithoutMounting
                                     relativeToURL:nil
                               bookmarkDataIsStale:nil
                                             error:&error];

    if (error != nil) {
        NSString *errorMessage = [NSString stringWithFormat:@"Error resolving URL from bookmark: %@", error];
        lua_pushnil(L) ;
        [skin pushNSObject:errorMessage] ;
        return 2 ;
    }

    if (url != nil){
        #define NSURLPathKey @"_NSURLPathKey"
        NSDictionary *values = [NSURL resourceValuesForKeys:@[NSURLPathKey] fromBookmarkData:bookmarkData];
        NSString *path = [values objectForKey:NSURLPathKey];
        [skin pushNSObject:path] ;
        return 1 ;
    }

    lua_pushnil(L) ;
    return 1 ;
}

/// hs.fs.urlFromPath(path) -> string | nil
/// Function
/// Returns the encoded URL from a path.
///
/// Parameters:
///  * path - The path
///
/// Returns:
///  * A string or `nil` if path is invalid.
static int fs_urlFromPath(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *filePath = [skin toNSObjectAtIndex:1];
    char *absolutePath = realpath([filePath stringByExpandingTildeInPath].UTF8String, NULL);

    if (!absolutePath) {
        lua_pushnil(L);
        return 1;
    }

    NSString *urlPath = [[filePath stringByStandardizingPath] stringByResolvingSymlinksInPath];
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:urlPath];

    [skin pushNSObject:fileURL.absoluteString] ;
    free(absolutePath);
    return 1 ;
}

static const struct luaL_Reg fslib[] = {
    {"attributes", file_info},
    {"chdir", change_dir},
    {"currentDir", get_dir},
    {"dir", dir_iter_factory},
    {"link", make_link},
    {"lock", file_lock},
    {"mkdir", make_dir},
    {"rmdir", remove_dir},
    {"symlinkAttributes", link_info},
//     {"setmode", lfs_f_setmode }, // noop for non Windows platforms
    {"touch", file_utime},
    {"unlock", file_unlock},
    {"lockDir", lfs_lock_dir},

    {"tagsAdd", tagsAdd},
    {"tagsRemove", tagsRemove},
    {"tagsSet", tagsSet},
    {"tagsGet", tagsGet},
    {"temporaryDirectory", hs_temporaryDirectory},
    {"fileUTI", hs_fileuti},
    {"fileUTIalternate", hs_fileUTIalternate},
    {"pathToAbsolute", hs_pathToAbsolute},
    {"displayName", fs_displayName},
    {"pathToBookmark", fs_pathToBookmark},
    {"pathFromBookmark", fs_pathFromBookmark},
    {"urlFromPath", fs_urlFromPath},
    {NULL, NULL},
};

int luaopen_hs_libfs (lua_State *L) {
    dir_create_meta (L);
    lock_create_meta (L);
    luaL_newlib (L, fslib);
    lua_pushvalue(L, -1);
    return 1;
}
