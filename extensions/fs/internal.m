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

#ifndef LFS_DO_NOT_USE_LARGE_FILE
#ifndef _WIN32
#ifndef _AIX
#define _FILE_OFFSET_BITS 64 /* Linux, Solaris and HP-UX */
#else
#define _LARGE_FILES 1 /* AIX */
#endif
#endif
#endif

#ifndef LFS_DO_NOT_USE_LARGE_FILE
#define _LARGEFILE64_SOURCE
#endif

#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <sys/stat.h>

#ifdef _WIN32
#include <direct.h>
#include <windows.h>
#include <io.h>
#include <sys/locking.h>
#ifdef __BORLANDC__
 #include <utime.h>
#else
 #include <sys/utime.h>
#endif
#include <fcntl.h>
#else
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/types.h>
#include <utime.h>
#endif

#include <Cocoa/Cocoa.h>
#include <LuaSkin/LuaSkin.h>

#include "lfs.h"

#define LFS_VERSION "1.6.2"
#define LFS_LIBNAME "fs"

#if LUA_VERSION_NUM >= 503 /* Lua 5.3 */

#ifndef luaL_optlong
#define luaL_optlong luaL_optinteger
#endif

#endif

#if LUA_VERSION_NUM < 502
#  define luaL_newlib(L,l) (lua_newtable(L), luaL_register(L,NULL,l))
#endif

/* Define 'strerror' for systems that do not implement it */
#ifdef NO_STRERROR
#define strerror(_)     "System unable to describe the error"
#endif

/* Define 'getcwd' for systems that do not implement it */
#ifdef NO_GETCWD
#define getcwd(p,s)     NULL
#define getcwd_error    "Function 'getcwd' not provided by system"
#else
#define getcwd_error    strerror(errno)
  #ifdef _WIN32
	 /* MAX_PATH seems to be 260. Seems kind of small. Is there a better one? */
    #define LFS_MAXPATHLEN MAX_PATH
  #else
	/* For MAXPATHLEN: */
    #include <sys/param.h>
    #define LFS_MAXPATHLEN MAXPATHLEN
  #endif
#endif

#define DIR_METATABLE "directory metatable"
typedef struct dir_data {
        int  closed;
#ifdef _WIN32
        intptr_t hFile;
        char pattern[MAX_PATH+1];
#else
        DIR *dir;
#endif
} dir_data;

#define LOCK_METATABLE "lock metatable"

#ifdef _WIN32
 #ifdef __BORLANDC__
  #define lfs_setmode(L,file,m)   ((void)L, setmode(_fileno(file), m))
  #define STAT_STRUCT struct stati64
 #else
  #define lfs_setmode(L,file,m)   ((void)L, _setmode(_fileno(file), m))
  #define STAT_STRUCT struct _stati64
 #endif
#define STAT_FUNC _stati64
#define LSTAT_FUNC STAT_FUNC
#else
#define _O_TEXT               0
#define _O_BINARY             0
#define lfs_setmode(L,file,m)   ((void)L, (void)file, (void)m, 0)
#define STAT_STRUCT struct stat
#define STAT_FUNC stat
#define LSTAT_FUNC lstat
#endif

/*
** Utility functions
*/
static int pusherror(lua_State *L, const char *info)
{
        lua_pushnil(L);
        if (info==NULL)
                lua_pushstring(L, strerror(errno));
        else
                lua_pushfstring(L, "%s: %s", info, strerror(errno));
        lua_pushinteger(L, errno);
        return 3;
}

static int pushresult(lua_State *L, int i, const char *info)
{
        if (i==-1)
                return pusherror(L, info);
        lua_pushinteger(L, i);
        return 1;
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
        const char *path = luaL_checkstring(L, 1);
        if (chdir(path)) {
                lua_pushnil (L);
                lua_pushfstring (L,"Unable to change working directory to '%s'\n%s\n",
                                path, chdir_error);
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
static int get_dir (lua_State *L) {
  char *path;
  /* Passing (NULL, 0) is not guaranteed to work. Use a temp buffer and size instead. */
  char buf[LFS_MAXPATHLEN];
  if ((path = getcwd(buf, LFS_MAXPATHLEN)) == NULL) {
    lua_pushnil(L);
    lua_pushstring(L, getcwd_error);
    return 2;
  }
  else {
    lua_pushstring(L, path);
    return 1;
  }
}

/*
** Check if the given element on the stack is a file and returns it.
*/
static FILE *check_file (lua_State *L, int idx, const char *funcname) {
        FILE **fh = (FILE **)luaL_checkudata (L, idx, "FILE*");
        if (fh == NULL) {
                luaL_error (L, "%s: not a file", funcname);
                return 0;
        } else if (*fh == NULL) {
                luaL_error (L, "%s: closed file", funcname);
                return 0;
        } else
                return *fh;
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
#ifdef _WIN32
        /* lkmode valid values are:
           LK_LOCK    Locks the specified bytes. If the bytes cannot be locked, the program immediately tries again after 1 second. If, after 10 attempts, the bytes cannot be locked, the constant returns an error.
           LK_NBLCK   Locks the specified bytes. If the bytes cannot be locked, the constant returns an error.
           LK_NBRLCK  Same as _LK_NBLCK.
           LK_RLCK    Same as _LK_LOCK.
           LK_UNLCK   Unlocks the specified bytes, which must have been previously locked.

           Regions should be locked only briefly and should be unlocked before closing a file or exiting the program.

           http://msdn.microsoft.com/library/default.asp?url=/library/en-us/vclib/html/_crt__locking.asp
        */
        int lkmode;
        switch (*mode) {
                case 'r': lkmode = LK_NBLCK; break;
                case 'w': lkmode = LK_NBLCK; break;
                case 'u': lkmode = LK_UNLCK; break;
                default : return luaL_error (L, "%s: invalid mode", funcname);
        }
        if (!len) {
                fseek (fh, 0L, SEEK_END);
                len = ftell (fh);
        }
        fseek (fh, start, SEEK_SET);
#ifdef __BORLANDC__
        code = locking (fileno(fh), lkmode, len);
#else
        code = _locking (fileno(fh), lkmode, len);
#endif
#else
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
#endif
        return (code != -1);
}

#ifdef _WIN32
typedef struct lfs_Lock {
  HANDLE fd;
} lfs_Lock;
static int lfs_lock_dir(lua_State *L) {
  size_t pathl; HANDLE fd;
  lfs_Lock *lock;
  char *ln;
  const char *lockfile = "/lockfile.lfs";
  const char *path = luaL_checklstring(L, 1, &pathl);
  ln = (char*)malloc(pathl + strlen(lockfile) + 1);
  if(!ln) {
    lua_pushnil(L); lua_pushstring(L, strerror(errno)); return 2;
  }
  strcpy(ln, path); strcat(ln, lockfile);
  if((fd = CreateFile(ln, GENERIC_WRITE, 0, NULL, CREATE_NEW,
                FILE_ATTRIBUTE_NORMAL | FILE_FLAG_DELETE_ON_CLOSE, NULL)) == INVALID_HANDLE_VALUE) {
        int en = GetLastError();
        free(ln); lua_pushnil(L);
        if(en == ERROR_FILE_EXISTS || en == ERROR_SHARING_VIOLATION)
                lua_pushstring(L, "File exists");
        else
                lua_pushstring(L, strerror(en));
        return 2;
  }
  free(ln);
  lock = (lfs_Lock*)lua_newuserdata(L, sizeof(lfs_Lock));
  lock->fd = fd;
  luaL_getmetatable (L, LOCK_METATABLE);
  lua_setmetatable (L, -2);
  return 1;
}
static int lfs_unlock_dir(lua_State *L) {
  lfs_Lock *lock = (lfs_Lock *)luaL_checkudata(L, 1, LOCK_METATABLE);
  if(lock->fd != INVALID_HANDLE_VALUE) {
    CloseHandle(lock->fd);
    lock->fd=INVALID_HANDLE_VALUE;
  }
  return 0;
}
#else
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
#endif

static int lfs_g_setmode (lua_State *L, FILE *f, int arg) {
  static const int mode[] = {_O_BINARY, _O_TEXT};
  static const char *const modenames[] = {"binary", "text", NULL};
  int op = luaL_checkoption(L, arg, NULL, modenames);
  int res = lfs_setmode(L, f, mode[op]);
  if (res != -1) {
    int i;
    lua_pushboolean(L, 1);
    for (i = 0; modenames[i] != NULL; i++) {
      if (mode[i] == res) {
        lua_pushstring(L, modenames[i]);
        goto exit;
      }
    }
    lua_pushnil(L);
  exit:
    return 2;
  } else {
    int en = errno;
    lua_pushnil(L);
    lua_pushfstring(L, "%s", strerror(en));
    lua_pushinteger(L, en);
    return 3;
  }
}

static int lfs_f_setmode(lua_State *L) {
  return lfs_g_setmode(L, check_file(L, 1, "setMode"), 2);
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
static int make_link(lua_State *L)
{
#ifndef _WIN32
        const char *oldpath = luaL_checkstring(L, 1);
        const char *newpath = luaL_checkstring(L, 2);
        return pushresult(L,
                (lua_toboolean(L,3) ? symlink : link)(oldpath, newpath), NULL);
#else
        return pusherror(L, "make_link is not supported on Windows");
#endif
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
        const char *path = luaL_checkstring (L, 1);
        int fail;
#ifdef _WIN32
        fail = _mkdir (path);
#else
        fail =  mkdir (path, S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP |
                             S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH );
#endif
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
        const char *path = luaL_checkstring (L, 1);
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
#ifdef _WIN32
        struct _finddata_t c_file;
#else
        struct dirent *entry;
#endif
        dir_data *d = (dir_data *)luaL_checkudata (L, 1, DIR_METATABLE);
        luaL_argcheck (L, d->closed == 0, 1, "closed directory");
#ifdef _WIN32
        if (d->hFile == 0L) { /* first entry */
                if ((d->hFile = _findfirst (d->pattern, &c_file)) == -1L) {
                        lua_pushnil (L);
                        lua_pushstring (L, strerror (errno));
                        d->closed = 1;
                        return 2;
                } else {
                        lua_pushstring (L, c_file.name);
                        return 1;
                }
        } else { /* next entry */
                if (_findnext (d->hFile, &c_file) == -1L) {
                        /* no more entries => close directory */
                        _findclose (d->hFile);
                        d->closed = 1;
                        return 0;
                } else {
                        lua_pushstring (L, c_file.name);
                        return 1;
                }
        }
#else
        if ((entry = readdir (d->dir)) != NULL) {
                lua_pushstring (L, entry->d_name);
                return 1;
        } else {
                /* no more entries => close directory */
                closedir (d->dir);
                d->closed = 1;
                return 0;
        }
#endif
}


/*
** Closes directory iterators
*/
static int dir_close (lua_State *L) {
        dir_data *d = (dir_data *)lua_touserdata (L, 1);
#ifdef _WIN32
        if (!d->closed && d->hFile) {
                _findclose (d->hFile);
        }
#else
        if (!d->closed && d->dir) {
                closedir (d->dir);
        }
#endif
        d->closed = 1;
        return 0;
}


/*
** Factory of directory iterators
*/
/// hs.fs.dir(path) -> iter_fn, dir_obj
/// Function
/// Creates an iterator for walking a filesystem path
///
/// Parameters:
///  * path - A string containing a directory to iterate
///
/// Returns:
///  * An iterator function
///  * A data object to pass to the iterator function
///
/// Notes:
///  * The data object should be passed to the iterator function. Each call will return either a string containing the name of an entry in the directory, or nil if there are no more entries.
///  * Iteration can also be performed by calling `:next()` on the data object. Note that if you do this, you must call `:close()` on the object when you have finished
///  * This function will raise a Lua error if it cannot iterate the supplied path
static int dir_iter_factory (lua_State *L) {
        const char *path = luaL_checkstring (L, 1);
        dir_data *d;
        lua_pushcfunction (L, dir_iter);
        d = (dir_data *) lua_newuserdata (L, sizeof(dir_data));
        luaL_getmetatable (L, DIR_METATABLE);
        lua_setmetatable (L, -2);
        d->closed = 0;
#ifdef _WIN32
        d->hFile = 0L;
        if (strlen(path) > MAX_PATH-2)
          luaL_error (L, "path too long: %s", path);
        else
          sprintf (d->pattern, "%s/*", path);
#else
        d->dir = opendir (path);
        if (d->dir == NULL)
          luaL_error (L, "cannot open %s: %s", path, strerror (errno));
#endif
        return 2;
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


#ifdef _WIN32
 #ifndef S_ISDIR
   #define S_ISDIR(mode)  (mode&_S_IFDIR)
 #endif
 #ifndef S_ISREG
   #define S_ISREG(mode)  (mode&_S_IFREG)
 #endif
 #ifndef S_ISLNK
   #define S_ISLNK(mode)  (0)
 #endif
 #ifndef S_ISSOCK
   #define S_ISSOCK(mode)  (0)
 #endif
 #ifndef S_ISFIFO
   #define S_ISFIFO(mode)  (0)
 #endif
 #ifndef S_ISCHR
   #define S_ISCHR(mode)  (mode&_S_IFCHR)
 #endif
 #ifndef S_ISBLK
   #define S_ISBLK(mode)  (0)
 #endif
#endif
/*
** Convert the inode protection mode to a string.
*/
#ifdef _WIN32
static const char *mode2string (unsigned short mode) {
#else
static const char *mode2string (mode_t mode) {
#endif
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
        const char *file = luaL_checkstring (L, 1);
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
#ifndef _WIN32
/* blocks allocated for file */
static void push_st_blocks (lua_State *L, STAT_STRUCT *info) {
        lua_pushinteger (L, (lua_Integer)info->st_blocks);
}
/* optimal file system I/O blocksize */
static void push_st_blksize (lua_State *L, STAT_STRUCT *info) {
        lua_pushinteger (L, (lua_Integer)info->st_blksize);
}
#endif

 /*
** Convert the inode protection mode to a permission list.
*/

#ifdef _WIN32
static const char *perm2string (unsigned short mode) {
  static char perms[10] = "---------";
  int i;
  for (i=0;i<9;i++) perms[i]='-';
  if (mode  & _S_IREAD)
   { perms[0] = 'r'; perms[3] = 'r'; perms[6] = 'r'; }
  if (mode  & _S_IWRITE)
   { perms[1] = 'w'; perms[4] = 'w'; perms[7] = 'w'; }
  if (mode  & _S_IEXEC)
   { perms[2] = 'x'; perms[5] = 'x'; perms[8] = 'x'; }
  return perms;
}
#else
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
#endif

/* permssions string */
static void push_st_perm (lua_State *L, STAT_STRUCT *info) {
    lua_pushstring (L, perm2string (info->st_mode));
}

typedef void (*_push_function) (lua_State *L, STAT_STRUCT *info);

struct _stat_members {
        const char *name;
        _push_function push;
};

struct _stat_members members[] = {
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
#ifndef _WIN32
        { "blocks",       push_st_blocks },
        { "blksize",      push_st_blksize },
#endif
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
///   * creation - A number containing the time the file was created (as seconds since the UNIX epoch)
///   * size - A number containing the file size, in bytes
///   * blocks - A number containing the number of blocks allocated for file
///   * blksize - A number containing the optimal file system I/O blocksize
///
/// Notes:
///  * This function uses `stat()` internally thus if the given filepath is a symbolic link, it is followed (if it points to another link the chain is followed recursively) and the information is about the file it refers to. To obtain information about the link itself, see function `hs.fs.symlinkAttributes()`
static int _file_info_ (lua_State *L, int (*st)(const char*, STAT_STRUCT*)) {
        STAT_STRUCT info;
        const char *file = luaL_checkstring (L, 1);
        int i;

        if (st(file, &info)) {
                lua_pushnil (L);
                lua_pushfstring (L, "cannot obtain information from file `%s'", file);
                return 2;
        }
        if (lua_isstring (L, 2)) {
                const char *member = lua_tostring (L, 2);
                for (i = 0; members[i].name; i++) {
                        if (strcmp(members[i].name, member) == 0) {
                                /* push member value and return */
                                members[i].push (L, &info);
                                return 1;
                        }
                }
                /* member not found */
                return luaL_error(L, "invalid attribute name");
        }
        /* creates a table if none is given */
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
/// hs.fs.symlinkAttributes (filepath [, aname]) -> table or string or nil,error
/// Function
/// Gets the attributes of a symbolic link
///
/// Parameters:
///  * filepath - A string containing the path of a link to inspect
///  * aName - An optional attribute name. If this value is specified, only the attribute requested, is returned
///
/// Returns:
///  * A table or string if the values could be found, otherwise nil and an error string.
///
/// Notes:
///  * The return values for this function are identical to those provided by `hs.fs.attributes()`
static int link_info (lua_State *L) {
        return _file_info_ (L, LSTAT_FUNC);
}

NSURL *path_to_nsurl(NSString *path) {
    return [NSURL fileURLWithPath:[path stringByExpandingTildeInPath]];
}

NSArray *tags_from_file(lua_State *L, NSString *filePath) {
    LuaSkin *skin = [LuaSkin shared];
    NSURL *url = path_to_nsurl(filePath);
    if (!url) {
        return nil;
    }

    NSArray *tags;
    NSError *error;
    if (![url getResourceValue:&tags forKey:NSURLTagNamesKey error:&error]) {
        [skin logError:[NSString stringWithFormat:@"hs.fs tags_from_file() Unable to get tags for %@: %@", url, [error localizedDescription]]];
        return nil;
    }

    return tags;
}

BOOL tags_to_file(lua_State *L, NSURL *url, NSArray *tags) {
    LuaSkin *skin = [LuaSkin shared];
    NSError *error;

    if (![url setResourceValue:tags forKey:NSURLTagNamesKey error:&error]) {
        [skin logError:[NSString stringWithFormat:@"hs.fs tags_to_file() Unable to set tags for %@: %@", url, [error localizedDescription]]];
        return false;
    }
    return true;
}

/// hs.fs.tagsGet(filepath) -> table or nil
/// Function
/// Gets the Finder tags of a file
///
/// Parameters:
///  * filepath - A string containing the path of a file
///
/// Returns:
///  * A table containing the list of the file's tags, or nil if an error occurred
static int tagsGet(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
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
///  * None
static int tagsAdd(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];
    NSURL *url = path_to_nsurl(path);
    NSArray *existingTags = tags_from_file(L, path);
    if (!existingTags || !url) {
        return 0;
    }

    NSMutableSet *oldTags = [NSMutableSet setWithArray:existingTags];
    NSMutableSet *newTags = [[NSMutableSet alloc] init];

    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        if (lua_type(L, -1) == LUA_TSTRING) {
            NSString *tag = [skin toNSObjectAtIndex:-1];
            [newTags addObject:tag];
        }

        lua_pop(L, 1);
    }

    [newTags unionSet:oldTags];

    tags_to_file(L, path_to_nsurl(path), [newTags allObjects]);

    return 0;
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
///  * None
static int tagsSet(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];
    NSURL *url = path_to_nsurl(path);
    if (!url) {
        return 0;
    }

    NSMutableArray *tags = [[NSMutableArray alloc] init];

    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        if (lua_type(L, -1) == LUA_TSTRING) {
            NSString *tag = [skin toNSObjectAtIndex:-1];
            [tags addObject:tag];
        }

        lua_pop(L, 1);
    }

    tags_to_file(L, url, tags);

    return 0;
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
///  * None
static int tagsRemove(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK];
    NSString *path = [skin toNSObjectAtIndex:1];
    NSURL *url = path_to_nsurl(path);
    NSArray *tags = tags_from_file(L, path);
    if (!url || !tags) {
        return 0;
    }

    NSMutableArray *removeTags = [[NSMutableArray alloc] init];

    lua_pushnil(L);
    while (lua_next(L, 2) != 0) {
        if (lua_type(L, -1) == LUA_TSTRING) {
            NSString *tag = [skin toNSObjectAtIndex:-1];
            [removeTags addObject:tag];
        }

        lua_pop(L, 1);
    }

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT SELF IN %@", removeTags];
    tags = [tags filteredArrayUsingPredicate:predicate];

    tags_to_file(L, url, tags);

    return 0;
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
        {"setMode", lfs_f_setmode},
        {"touch", file_utime},
        {"unlock", file_unlock},
        {"lockDir", lfs_lock_dir},
        {"tagsAdd", tagsAdd},
        {"tagsRemove", tagsRemove},
        {"tagsSet", tagsSet},
        {"tagsGet", tagsGet},
        {"temporaryDirectory", hs_temporaryDirectory},
        {NULL, NULL},
};

int luaopen_hs_fs_internal (lua_State *L) {
        dir_create_meta (L);
        lock_create_meta (L);
        luaL_newlib (L, fslib);
        lua_pushvalue(L, -1);
        return 1;
}
