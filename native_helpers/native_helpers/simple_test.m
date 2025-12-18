#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

static volatile bool shouldContinue = true;

void signalHandler(int signal) {
    printf("Signal received: %d\n", signal);
    fflush(stdout);
    shouldContinue = false;
}

CGEventRef eventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    printf("Event: type=%d\n", type);
    fflush(stdout);
    return event;
}

int main() {
    @autoreleasepool {
        printf("Simple test starting...\n");
        fflush(stdout);
        
        signal(SIGINT, signalHandler);
        signal(SIGTERM, signalHandler);
        
        printf("Creating event tap...\n");
        fflush(stdout);
        
        CGEventMask eventMask = CGEventMaskBit(kCGEventLeftMouseDown);
        CFMachPortRef eventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGHeadInsertEventTap,
            kCGEventTapOptionListenOnly,
            eventMask,
            eventCallback,
            NULL
        );
        
        if (!eventTap) {
            printf("Failed to create event tap\n");
            fflush(stdout);
            return 1;
        }
        
        printf("Event tap created successfully\n");
        fflush(stdout);
        
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(eventTap, true);
        
        printf("Event capture ready\n");
        fflush(stdout);
        
        while (shouldContinue) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
        }
        
        printf("Shutting down\n");
        fflush(stdout);
        
        CGEventTapEnable(eventTap, false);
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CFRelease(eventTap);
        
        printf("Clean exit\n");
        fflush(stdout);
        return 0;
    }
}