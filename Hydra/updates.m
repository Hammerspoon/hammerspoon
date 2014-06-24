#import "hydra.h"
#include <CommonCrypto/CommonDigest.h>

static SecKeyRef transform_public_key(NSString* pubkeypath) {
	CFArrayRef items = NULL;
    SecKeyRef security_key = NULL;
    
    NSString* pubkey = [NSString stringWithContentsOfFile:pubkeypath encoding:NSUTF8StringEncoding error:NULL];
    NSData* pubkeyData = [pubkey dataUsingEncoding:NSUTF8StringEncoding];
    if ([pubkeyData length] == 0) goto cleanup;
    
	SecExternalFormat format = kSecFormatOpenSSL;
	SecExternalItemType itemType = kSecItemTypePublicKey;
	SecItemImportExportKeyParameters parameters = {};
    
	OSStatus status = SecItemImport((__bridge CFDataRef)pubkeyData, NULL, &format, &itemType, 0, &parameters, NULL, &items);
    if (status != noErr || items == NULL ||
        format != kSecFormatOpenSSL || itemType != kSecItemTypePublicKey ||
        CFArrayGetCount(items) != 1)
        goto cleanup;
    
    security_key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    
cleanup:
    if (items) CFRelease(items);
    return security_key;
}


static BOOL updater_verify_file(NSString* sig, NSString* pubkeypath, NSString* zipfilepath) {
    BOOL verified = NO;
    
    SecKeyRef security_key = NULL;
    
    NSData *signature = nil;
    NSInputStream *input_stream = nil;
    
	SecGroupTransformRef group = SecTransformCreateGroupTransform();
	SecTransformRef read_transform = NULL;
	SecTransformRef digest_transform = NULL;
	SecTransformRef verify_transform = NULL;
	CFErrorRef error = NULL;
    
    security_key = transform_public_key(pubkeypath);
    if (security_key == NULL) goto cleanup;
    
	signature = [[NSData alloc] initWithBase64EncodedString:[sig stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (signature == nil) goto cleanup;
    
	input_stream = [NSInputStream inputStreamWithFileAtPath:zipfilepath];
    if (input_stream == nil) goto cleanup;
    
	read_transform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)input_stream);
	if (read_transform == NULL) goto cleanup;
    
	digest_transform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, NULL);
	if (digest_transform == NULL) goto cleanup;
    
	verify_transform = SecVerifyTransformCreate(security_key, (__bridge CFDataRef)signature, NULL);
	if (verify_transform == NULL) goto cleanup;
    
	SecTransformConnectTransforms(read_transform, kSecTransformOutputAttributeName, digest_transform, kSecTransformInputAttributeName, group, &error);
	if (error) goto cleanup;
    
	SecTransformConnectTransforms(digest_transform, kSecTransformOutputAttributeName, verify_transform, kSecTransformInputAttributeName, group, &error);
	if (error) goto cleanup;
    
	verified = [CFBridgingRelease(SecTransformExecute(group, NULL)) boolValue];
    
cleanup:
    
    if (group) CFRelease(group);
    if (security_key) CFRelease(security_key);
    if (read_transform) CFRelease(read_transform);
    if (digest_transform) CFRelease(digest_transform);
    if (verify_transform) CFRelease(verify_transform);
    if (error) CFRelease(error);
    
    return verified;
}

static hydradoc doc_updates_check = {
    "updates", "check", "api.updates.check()",
    "Checks (over the internet) for an update. If one is available, calls api.updates.available(newversion, currentversion, changelog)."
};

static NSString* version_url = @"https://raw.githubusercontent.com/sdegutis/Hydra/master/version.txt";
static NSString* download_url = @"https://raw.githubusercontent.com/sdegutis/Hydra/master/Builds/Hydra-LATEST.app.tar.gz";
static NSString* changelog_url = @"https://raw.githubusercontent.com/sdegutis/Hydra/master/CHANGES.txt";

static NSString* tempDir(void) {
    NSString* tmpdir = NSTemporaryDirectory();
    if (tmpdir == nil) tmpdir = @"/tmp";
    
    NSString* template = [tmpdir stringByAppendingPathComponent:@"hydra.XXXXXX"];
    NSMutableData * bufferData = [[template dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    char* buffer = [bufferData mutableBytes];
    mkdtemp(buffer);
    return [NSString stringWithUTF8String:buffer];
}

void no_new_version_yet(lua_State* L) {
    lua_getglobal(L, "api");
    lua_getfield(L, -1, "updates");
    lua_getfield(L, -1, "notyet");
    
    if (lua_isfunction(L, -1)) {
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        
        lua_pop(L, 2);
    }
    else {
        lua_pop(L, 3);
    }
}

static NSString* app_zip_path;

void continue_check(lua_State* L, NSArray* parts) {
    NSString* versionPath = [[NSBundle mainBundle] pathForResource:@"version" ofType:@"txt"];
    NSString* currentVersionInfo = [NSString stringWithContentsOfFile:versionPath encoding:NSUTF8StringEncoding error:NULL];
    NSArray* currentVersionParts = [currentVersionInfo componentsSeparatedByString:@"\n"];
    
    NSInteger releaseDate = [[parts objectAtIndex:0] integerValue];
    NSInteger currentDate = [[currentVersionParts objectAtIndex:0] integerValue];
    
    if (releaseDate == currentDate) { printf("checked for update but found none yet\n"); no_new_version_yet(L); return; }
    if (releaseDate < currentDate)  { printf("somehow you have a newer version than currently exists; congratulations\n"); return; }
    
    NSString* newVersion = [parts objectAtIndex:1];
    NSString* currentVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    
    NSString* signature = [parts objectAtIndex:2];
    NSInteger filesize = [[parts objectAtIndex:3] integerValue];
    
    NSString* pubkeypath = [[NSBundle mainBundle] pathForResource:@"dsa_pub" ofType:@"cer"];
    
    NSURL* url = [NSURL URLWithString:download_url];
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if ([(NSHTTPURLResponse*)response statusCode] != 200) { printf("checked for update but download url is broken(?)\n"); return; }
                               
                               if (filesize != [data length]) { printf("found update but filesize didn't match what was expected\n"); return; }
                               
                               NSString* temporaryDirectory = tempDir();
                               if (!temporaryDirectory) { printf("found update but couldn't save it to a temp dir for some reason\n"); return; }
                               
                               app_zip_path = [temporaryDirectory stringByAppendingPathComponent:@"Hydra-LATEST.app.tar.gz"];
                               [data writeToFile:app_zip_path atomically:YES];
                               
                               BOOL verified = updater_verify_file(signature, pubkeypath, app_zip_path);
                               
                               if (!verified) { printf("found update but file didn't verify\n"); return; }
                               
                               NSURL* url = [NSURL URLWithString:changelog_url];
                               NSURLRequest* req = [NSURLRequest requestWithURL:url];
                               [NSURLConnection sendAsynchronousRequest:req
                                                                  queue:[NSOperationQueue mainQueue]
                                                      completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                                                          NSString* changelog = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                                          
                                                          lua_getglobal(L, "api");
                                                          lua_getfield(L, -1, "updates");
                                                          lua_getfield(L, -1, "available");
                                                          
                                                          if (lua_isfunction(L, -1)) {
                                                              lua_pushstring(L, [newVersion UTF8String]);
                                                              lua_pushstring(L, [currentVersion UTF8String]);
                                                              lua_pushstring(L, [changelog UTF8String]);
                                                              
                                                              if (lua_pcall(L, 3, 0, 0))
                                                                  hydra_handle_error(L);
                                                              
                                                              lua_pop(L, 2);
                                                          }
                                                          else {
                                                              lua_pop(L, 3);
                                                              printf("found update but api.updates.available is nil; see the docs for it to fix this\n");
                                                          }
                                                      }];
                           }];
}

int updates_check(lua_State* L) {
    NSURL* url = [NSURL URLWithString:version_url];
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               if ([(NSHTTPURLResponse*)response statusCode] != 200) { printf("checked for update but version url is broken(?)\n"); return; }
                               
                               NSString* str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                               if ([str length] == 0) { printf("checked for update but version file is messed up somehow\n"); return; }
                               
                               NSArray* parts = [str componentsSeparatedByString:@"\n"];
                               if ([parts count] != 5) { printf("checked for update but version file is all weird and stuff\n"); return; }
                               
                               continue_check(L, parts);
                           }];
    return 0;
}

static hydradoc doc_updates_install = {
    "updates", "install", "api.updates.install()",
    "Installs the update, if it was made available by api.updates.check(); restarts the app."
};

int updates_install(lua_State* L) {
    NSString* destParentDir = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
    NSString* horribleShellCommand = [NSString stringWithFormat:@"tar -zxf \"%@\" -C \"%@\"; sleep 0.5; open -a Hydra", app_zip_path, destParentDir];
    
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/sh"];
    [task setArguments: @[@"-c", horribleShellCommand]];
    [task launch];
    
    [NSApp terminate: nil];
    exit(0); // lol
    return 0; // LOL
}

static const luaL_Reg updateslib[] = {
    {"check", updates_check},
    {NULL, NULL}
};

int luaopen_updates(lua_State* L) {
    hydra_add_doc_group(L, "updates", "Check for and install Hydra updates.");
    hydra_add_doc_item(L, &doc_updates_check);
    hydra_add_doc_item(L, &doc_updates_install);
    
    luaL_newlib(L, updateslib);
    return 1;
}
