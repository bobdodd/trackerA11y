#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

// Test callback - just to see if it works
CGEventRef testCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    printf("Event captured: type=%d\n", type);
    fflush(stdout);
    return event;
}

int main() {
    @autoreleasepool {
        printf("Debug: Helper starting...\n");
        printf("Debug: macOS version check...\n");
        fflush(stdout);
        
        // Check if we can create an event tap at all
        printf("Debug: Testing kCGSessionEventTap...\n");
        fflush(stdout);
        
        CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown);
        CFMachPortRef eventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            eventMask,
            testCallback,
            NULL
        );
        
        if (!eventTap) {
            printf("ERROR: kCGSessionEventTap failed\n");
            printf("Debug: Testing kCGHIDEventTap...\n");
            fflush(stdout);
            
            // Try HID event tap instead
            eventTap = CGEventTapCreate(
                kCGHIDEventTap,
                kCGHeadInsertEventTap,
                kCGEventTapOptionListenOnly,
                eventMask,
                testCallback,
                NULL
            );
            
            if (!eventTap) {
                printf("ERROR: Both kCGSessionEventTap and kCGHIDEventTap failed\n");
                printf("This indicates missing Accessibility permissions\n");
                printf("Or process running in restricted environment\n");
                fflush(stdout);
                return 1;
            } else {
                printf("SUCCESS: kCGHIDEventTap created\n");
                fflush(stdout);
            }
        } else {
            printf("SUCCESS: kCGSessionEventTap created\n");
            fflush(stdout);
        }
        
        // Test if the tap actually works
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        if (!runLoopSource) {
            printf("ERROR: Failed to create run loop source\n");
            CFRelease(eventTap);
            return 1;
        }
        
        printf("SUCCESS: Run loop source created\n");
        printf("Debug: Testing event capture for 2 seconds... click something!\n");
        fflush(stdout);
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(eventTap, true);
        
        // Run for 2 seconds
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 2.0, false);
        
        printf("Debug: Cleaning up\n");
        CGEventTapEnable(eventTap, false);
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CFRelease(eventTap);
        
        printf("Debug: Helper exiting normally\n");
        fflush(stdout);
        return 0;
    }
}