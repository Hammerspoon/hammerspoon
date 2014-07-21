#include <CoreFoundation/CoreFoundation.h>
#include <getopt.h>
#include <editline/readline.h>

static void hydra_setprefix(CFMutableStringRef inputstr, bool israw) {
    CFStringAppendCString(inputstr, israw ? "r" : "x", kCFStringEncodingUTF8);
}

static void hydra_send(CFMessagePortRef port, CFMutableStringRef inputstr) {
    CFDataRef inputData = CFStringCreateExternalRepresentation(NULL, inputstr, kCFStringEncodingUTF8, 0);
    
    CFDataRef returnedData;
    SInt32 code = CFMessagePortSendRequest(port, 0, inputData, 2, 4, kCFRunLoopDefaultMode, &returnedData);
    CFRelease(inputData);
    
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
        exit(2);
    }
    
    CFStringRef responseString = CFStringCreateFromExternalRepresentation(NULL, returnedData, kCFStringEncodingUTF8);
    CFRelease(returnedData);
    
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength(responseString), kCFStringEncodingUTF8);
    const char* responseCStringPtr = CFStringGetCStringPtr(responseString, kCFStringEncodingUTF8);
    char responseCString[maxSize];
    
    if (!responseCStringPtr)
        CFStringGetCString(responseString, (char *) responseCString, maxSize, kCFStringEncodingUTF8);
    
    printf("%s\n", responseCStringPtr ? responseCStringPtr : responseCString);
    
    CFRelease(responseString);
}

int main(int argc, char * argv[]) {
    bool israw = false;
    bool readstdin = false;
    char* code = NULL;
    
    int ch;
    while ((ch = getopt(argc, argv, "irc:sh")) != -1) {
        switch (ch) {
            case 'i': break;
            case 'r': israw = true; break;
            case 'c': code = optarg; break;
            case 's': readstdin = true; break;
            case 'h': case '?': default:
                printf("usage: %s [-i | -s | -c code] [-r]\n", argv[0]);
                exit(0);
        }
    }
    argc -= optind;
    argv += optind;
    
    CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("hydra"));
    
    if (!port) {
        fprintf(stderr, "error: can't access Hydra; is it running?\n");
        return 1;
    }
    
    CFMutableStringRef str = CFStringCreateMutable(NULL, 0);
    
    if (readstdin) {
        hydra_setprefix(str, israw);
        
        char buffer[BUFSIZ];
        while (fgets(buffer, BUFSIZ, stdin))
            CFStringAppendCString(str, buffer, kCFStringEncodingUTF8);
        
        if (ferror(stdin)) {
            perror("error reading from stdin.");
            exit(3);
        }
        
        hydra_send(port, str);
    }
    else if (code) {
        hydra_setprefix(str, israw);
        CFStringAppendCString(str, code, kCFStringEncodingUTF8);
        hydra_send(port, str);
    }
    else {
        puts("Hydra interactive prompt.");
        
        while (1) {
            char* input = readline("> ");
            if (!input)
                return 0;
            add_history(input);
            
            hydra_setprefix(str, israw);
            CFStringAppendCString(str, input, kCFStringEncodingUTF8);
            hydra_send(port, str);
            CFStringDelete(str, CFRangeMake(0, CFStringGetLength(str)));
            
            free(input);
        }
    }
    
    return 0;
}
