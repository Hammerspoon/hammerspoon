#include <CoreFoundation/CoreFoundation.h>
#include <getopt.h>

int main(int argc, char * argv[]) {
    bool raw = false;
    bool readstdin;
    
    int ch;
    static struct option longopts[] = {
        { "raw",   no_argument,  NULL,   'r' },
        { "help",  no_argument,  NULL,   'h' },
        { NULL,    0,            NULL,   0 },
    };
    
    while ((ch = getopt_long(argc, argv, "rh", longopts, NULL)) != -1) {
        switch (ch) {
            case 'r':
                raw = true;
                break;
            case 'h':
            default:
                printf("usage: %s [-r] <code>\n", argv[0]);
                exit(0);
        }
    }
    argc -= optind;
    argv += optind;
    
    readstdin = (argc == 0);
    
    CFStringRef initial = raw ? CFSTR("r") : CFSTR("x");
    CFMutableStringRef inputstr = CFStringCreateMutableCopy(NULL, 0, initial);
    
    if (readstdin) {
        char buffer[1024];
        while (fgets(buffer, 1024, stdin)) {
            CFStringRef tmp = CFStringCreateWithCString(NULL, buffer, kCFStringEncodingUTF8);
            CFStringAppend(inputstr, tmp);
        }
        
        if (ferror(stdin)) {
            perror("error reading from stdin.");
            exit(3);
        }
    }
    else {
        for (int i = 0; i < argc; i++) {
            if (i > 1) CFStringAppendCString(inputstr, " ", kCFStringEncodingUTF8);
            CFStringAppendCString(inputstr, argv[i], kCFStringEncodingUTF8);
        }
    }
    
    CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("hydra"));
    
    if (!port) {
        fprintf(stderr, "error: can't access Hydra; is it running?\n");
        return 1;
    }
    
    CFDataRef data = CFStringCreateExternalRepresentation(NULL, inputstr, kCFStringEncodingUTF8, 0);
    
    CFDataRef returnedData;
    SInt32 code = CFMessagePortSendRequest(port, 0, data, 2, 4, kCFRunLoopDefaultMode, &returnedData);
    
    if (code != kCFMessagePortSuccess) {
        const char* errstr = "unknown error";
        switch (code) {
            case kCFMessagePortSendTimeout: errstr = "send timeout"; break;
            case kCFMessagePortReceiveTimeout: errstr = "receive timeout"; break;
            case kCFMessagePortIsInvalid: errstr = "dunno something went wrong"; break;
            case kCFMessagePortTransportError: errstr = "error occurred while sending"; break;
            case kCFMessagePortBecameInvalidError: errstr = "osx is suddenly broken"; break;
        }
        
        fprintf(stderr, "error: %s\n", errstr);
        return 2;
    }
    
    CFStringRef response = CFStringCreateFromExternalRepresentation(NULL, returnedData, kCFStringEncodingUTF8);
    
    const char* outstr = CFStringGetCStringPtr(response, kCFStringEncodingUTF8);
    printf("%s\n", outstr);
    
    return 0;
}
