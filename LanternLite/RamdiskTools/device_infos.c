#include <stdio.h>
#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include "device_info.h"
#include "util.h"

int main(int argc, char* argv[])
{
    CFMutableDictionaryRef out = device_info(-1, NULL);
    
    if (out == NULL)
    {
        fprintf(stderr, "device_info(-1, NULL) failed\n");
        return -1;
    }
    
    if (argc > 1 )
    {
        CFStringRef key = CFStringCreateWithCString(kCFAllocatorDefault, argv[1], kCFStringEncodingASCII);
        CFTypeRef value = CFDictionaryGetValue(out, key);
        if (value != NULL)
        {
            *stderr = *stdout;//HAX
            CFShow(value);
        }
        else
            fprintf(stderr, "key %s not found\n", argv[1]);
        CFRelease(key);
        CFRelease(out);
        return 0;
    }

    saveResults(CFSTR("keys.plist"), out);
    CFRelease(out);
    
    return 0;
}
