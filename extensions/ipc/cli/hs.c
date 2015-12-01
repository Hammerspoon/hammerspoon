#include <CoreFoundation/CoreFoundation.h>
#include <getopt.h>
#include <editline/readline.h>

static char* COLOR_INITIAL = "";
static char* COLOR_INPUT = "";
static char* COLOR_OUTPUT = "";
static char* COLOR_RESET = "";

char * CFStringCopyUTF8String(CFStringRef aString) {
    if (aString == NULL) { return NULL; }

    CFIndex length = CFStringGetLength(aString);
    CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8);
    char *buffer = (char *)malloc(maxSize);
    if (CFStringGetCString(aString, buffer, maxSize, kCFStringEncodingUTF8)) {
        return buffer;
    }
    return "";
}

static void setupcolors(void) {
    COLOR_INITIAL = "\033[35m";
    // COLOR_INPUT = "\e[34m";
    COLOR_INPUT = "\033[33m";
    COLOR_OUTPUT = "\033[36m";
    COLOR_RESET = "\033[0m";

    CFStringRef initial = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_initial"), CFSTR("org.hammerspoon.Hammerspoon")) ;
    CFStringRef input = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_input"), CFSTR("org.hammerspoon.Hammerspoon")) ;
    CFStringRef output = CFPreferencesCopyAppValue(CFSTR("ipc.cli.color_output"), CFSTR("org.hammerspoon.Hammerspoon")) ;

    if (initial) { COLOR_INITIAL = CFStringCopyUTF8String(initial) ; }
    if (input) { COLOR_INPUT = CFStringCopyUTF8String(input) ; }
    if (output) { COLOR_OUTPUT = CFStringCopyUTF8String(output) ; }
}

static void target_setprefix(CFMutableStringRef inputstr, bool israw) {
    CFStringAppendCString(inputstr, israw ? "r" : "x", kCFStringEncodingUTF8);
}

static void target_send(CFMessagePortRef port, CFMutableStringRef inputstr) {
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

//     CFStringRef responseString = CFStringCreateFromExternalRepresentation(NULL, returnedData, kCFStringEncodingUTF8);
//     CFRelease(returnedData);
//     CFIndex maxSize = CFStringGetMaximumSizeForEncoding(CFStringGetLength(responseString), kCFStringEncodingUTF8) + 1;
//     const char* responseCStringPtr = CFStringGetCStringPtr(responseString, kCFStringEncodingUTF8);
//     char responseCString[maxSize];
//
//     if (!responseCStringPtr)
//         CFStringGetCString(responseString, responseCString, maxSize, kCFStringEncodingUTF8);
//     printf("%s%s%s\n", COLOR_OUTPUT, responseCStringPtr ? responseCStringPtr : responseCString, COLOR_RESET);
//
//     CFRelease(responseString);

    CFIndex maxSize = CFDataGetLength(returnedData) ;
    char  responseCString[maxSize] ;

    CFDataGetBytes(returnedData, CFRangeMake(0,maxSize), (UInt8 *)responseCString );

    printf("%s", COLOR_OUTPUT) ;
    fwrite(responseCString, 1, maxSize, stdout);
    printf("%s", COLOR_RESET) ;
}

void usage(char *argv0) {
    printf("usage: %s [-i | -s | -c code] [-r] [-n]\n", argv0);
    exit(0);
}

void sigint_handler(int signo) {
    printf("%s", COLOR_RESET);
    exit(0);
}

int main(int argc, char * argv[]) {
    signal(SIGINT, sigint_handler);

    bool israw = false;
    bool readstdin = false;
    char* code = NULL;
    bool usecolors = true;

    int ch;
    while ((ch = getopt(argc, argv, "nirc:sh")) != -1) {
        switch (ch) {
            case 'n': usecolors = false; break;
            case 'i': break;
            case 'r': israw = true; break;
            case 'c': code = optarg; break;
            case 's': readstdin = true; break;
            case 'h': case '?': default:
                usage(argv[0]);
        }
    }

    if (optind != argc) usage(argv[0]);

    argc -= optind;
    argv += optind;

    CFMessagePortRef port = CFMessagePortCreateRemote(NULL, CFSTR("Hammerspoon"));

    if (!port) {
        fprintf(stderr, "error: can't access Hammerspoon; is it running with the ipc module loaded?\n");
        return 1;
    }

    CFMutableStringRef str = CFStringCreateMutable(NULL, 0);

    if (readstdin) {
        target_setprefix(str, israw);

        char buffer[BUFSIZ];
        while (fgets(buffer, BUFSIZ, stdin))
            CFStringAppendCString(str, buffer, kCFStringEncodingUTF8);

        if (ferror(stdin)) {
            perror("error reading from stdin.");
            exit(3);
        }

        target_send(port, str);
    }
    else if (code) {
        target_setprefix(str, israw);
        CFStringAppendCString(str, code, kCFStringEncodingUTF8);
        target_send(port, str);
    }
    else {
        if (usecolors)
            setupcolors();

        printf("%sHammerspoon interactive prompt.%s\n", COLOR_INITIAL, COLOR_RESET);

        while (1) {
            printf("\n%s", COLOR_INPUT);
            char* input = readline("> ");
            printf("%s", COLOR_RESET);
            if (!input) { printf("\n") ; exit(0); }
            add_history(input);

            if (!CFMessagePortIsValid(port)) {
                fprintf(stderr, "%sMessage port has become invalid.  Attempting to re-establish.%s\n", COLOR_INITIAL, COLOR_RESET);
                port = CFMessagePortCreateRemote(NULL, CFSTR("Hammerspoon"));
                if (!port) {
                    fprintf(stderr, "error: can't access Hammerspoon; is it running?\n");
                    exit(1);
                }

            }

            target_setprefix(str, israw);
            CFStringAppendCString(str, input, kCFStringEncodingUTF8);
            target_send(port, str);
            CFStringDelete(str, CFRangeMake(0, CFStringGetLength(str)));

            free(input);
        }
    }

    return 0;
}
