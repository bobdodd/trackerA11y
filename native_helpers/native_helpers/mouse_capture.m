/**
 * Native macOS Mouse and Keyboard Event Capture
 * Uses Quartz Event Services to capture real system events
 * Outputs JSON for Node.js to consume
 */

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
#import <AppKit/AppKit.h>

// Global flag for clean shutdown
static volatile bool shouldContinue = true;

// Track last focused element to suppress duplicates
static NSString* lastFocusedElementSignature = nil;

// Forward declarations
void outputEvent(NSString* eventType, NSDictionary* eventData);

// Get UI element information at screen coordinates using AXUIElement API
NSDictionary* getElementAtPoint(CGFloat x, CGFloat y) {
    AXUIElementRef systemWide = AXUIElementCreateSystemWide();
    AXUIElementRef element = NULL;
    
    AXError error = AXUIElementCopyElementAtPosition(systemWide, x, y, &element);
    CFRelease(systemWide);
    
    if (error != kAXErrorSuccess || element == NULL) {
        return nil;
    }
    
    NSMutableDictionary* info = [NSMutableDictionary dictionary];
    
    // Get role
    CFTypeRef roleRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &roleRef) == kAXErrorSuccess && roleRef) {
        info[@"role"] = (__bridge_transfer NSString*)roleRef;
    }
    
    // Get title
    CFTypeRef titleRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXTitleAttribute, &titleRef) == kAXErrorSuccess && titleRef) {
        info[@"title"] = (__bridge_transfer NSString*)titleRef;
    }
    
    // Get description (accessibility label)
    CFTypeRef descRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute, &descRef) == kAXErrorSuccess && descRef) {
        info[@"label"] = (__bridge_transfer NSString*)descRef;
    }
    
    // Get value
    CFTypeRef valueRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXValueAttribute, &valueRef) == kAXErrorSuccess && valueRef) {
        if (CFGetTypeID(valueRef) == CFStringGetTypeID()) {
            info[@"value"] = (__bridge_transfer NSString*)valueRef;
        } else {
            CFRelease(valueRef);
        }
    }
    
    // Get role description (human-readable role)
    CFTypeRef roleDescRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXRoleDescriptionAttribute, &roleDescRef) == kAXErrorSuccess && roleDescRef) {
        info[@"roleDescription"] = (__bridge_transfer NSString*)roleDescRef;
    }
    
    // Get help text
    CFTypeRef helpRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXHelpAttribute, &helpRef) == kAXErrorSuccess && helpRef) {
        info[@"help"] = (__bridge_transfer NSString*)helpRef;
    }
    
    // Get enabled state
    CFTypeRef enabledRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXEnabledAttribute, &enabledRef) == kAXErrorSuccess && enabledRef) {
        info[@"enabled"] = (__bridge NSNumber*)enabledRef;
        CFRelease(enabledRef);
    }
    
    // Get focused state
    CFTypeRef focusedRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXFocusedAttribute, &focusedRef) == kAXErrorSuccess && focusedRef) {
        info[@"focused"] = (__bridge NSNumber*)focusedRef;
        CFRelease(focusedRef);
    }
    
    // Get position and size for bounds
    CFTypeRef posRef = NULL;
    CFTypeRef sizeRef = NULL;
    if (AXUIElementCopyAttributeValue(element, kAXPositionAttribute, &posRef) == kAXErrorSuccess && posRef) {
        CGPoint pos;
        if (AXValueGetValue(posRef, kAXValueCGPointType, &pos)) {
            info[@"boundsX"] = @(pos.x);
            info[@"boundsY"] = @(pos.y);
        }
        CFRelease(posRef);
    }
    if (AXUIElementCopyAttributeValue(element, kAXSizeAttribute, &sizeRef) == kAXErrorSuccess && sizeRef) {
        CGSize size;
        if (AXValueGetValue(sizeRef, kAXValueCGSizeType, &size)) {
            info[@"boundsWidth"] = @(size.width);
            info[@"boundsHeight"] = @(size.height);
        }
        CFRelease(sizeRef);
    }
    
    // Get the owning application
    pid_t pid = 0;
    if (AXUIElementGetPid(element, &pid) == kAXErrorSuccess) {
        info[@"pid"] = @(pid);
        
        // Get application name from pid
        NSRunningApplication* app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
        if (app.localizedName) {
            info[@"applicationName"] = app.localizedName;
        }
    }
    
    CFRelease(element);
    
    // Only return if we got useful info
    if (info[@"role"] || info[@"title"] || info[@"label"]) {
        return info;
    }
    
    return nil;
}

// Get the currently focused UI element system-wide
NSDictionary* getFocusedElement(void) {
    // Get the frontmost application
    NSRunningApplication* frontApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (!frontApp) {
        return nil;
    }
    
    // Create AXUIElement for the frontmost app
    AXUIElementRef appElement = AXUIElementCreateApplication(frontApp.processIdentifier);
    if (!appElement) {
        return nil;
    }
    
    // Get the focused UI element
    AXUIElementRef focusedElement = NULL;
    AXError error = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute, (CFTypeRef*)&focusedElement);
    CFRelease(appElement);
    
    if (error != kAXErrorSuccess || !focusedElement) {
        return nil;
    }
    
    NSMutableDictionary* info = [NSMutableDictionary dictionary];
    
    // Get role
    CFTypeRef roleRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute, &roleRef) == kAXErrorSuccess && roleRef) {
        info[@"role"] = (__bridge_transfer NSString*)roleRef;
    }
    
    // Get subrole (important for web elements)
    CFTypeRef subroleRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXSubroleAttribute, &subroleRef) == kAXErrorSuccess && subroleRef) {
        info[@"subrole"] = (__bridge_transfer NSString*)subroleRef;
    }
    
    // Get title
    CFTypeRef titleRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXTitleAttribute, &titleRef) == kAXErrorSuccess && titleRef) {
        info[@"title"] = (__bridge_transfer NSString*)titleRef;
    }
    
    // Get description (accessibility label - often contains web element info)
    CFTypeRef descRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXDescriptionAttribute, &descRef) == kAXErrorSuccess && descRef) {
        info[@"label"] = (__bridge_transfer NSString*)descRef;
    }
    
    // Get value
    CFTypeRef valueRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXValueAttribute, &valueRef) == kAXErrorSuccess && valueRef) {
        if (CFGetTypeID(valueRef) == CFStringGetTypeID()) {
            info[@"value"] = (__bridge_transfer NSString*)valueRef;
        } else {
            CFRelease(valueRef);
        }
    }
    
    // Get role description
    CFTypeRef roleDescRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXRoleDescriptionAttribute, &roleDescRef) == kAXErrorSuccess && roleDescRef) {
        info[@"roleDescription"] = (__bridge_transfer NSString*)roleDescRef;
    }
    
    // Get help text
    CFTypeRef helpRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXHelpAttribute, &helpRef) == kAXErrorSuccess && helpRef) {
        info[@"help"] = (__bridge_transfer NSString*)helpRef;
    }
    
    // Get DOM identifier if available (Safari exposes this for web elements)
    CFTypeRef domIdRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXDOMIdentifier"), &domIdRef) == kAXErrorSuccess && domIdRef) {
        info[@"domId"] = (__bridge_transfer NSString*)domIdRef;
    }
    
    // Get DOM class list if available
    CFTypeRef domClassRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXDOMClassList"), &domClassRef) == kAXErrorSuccess && domClassRef) {
        if (CFGetTypeID(domClassRef) == CFArrayGetTypeID()) {
            info[@"domClassList"] = (__bridge_transfer NSArray*)domClassRef;
        } else {
            CFRelease(domClassRef);
        }
    }
    
    // Get URL attribute (for links and current page)
    CFTypeRef urlRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXURLAttribute, &urlRef) == kAXErrorSuccess && urlRef) {
        if (CFGetTypeID(urlRef) == CFURLGetTypeID()) {
            CFURLRef url = (CFURLRef)urlRef;
            info[@"url"] = (__bridge_transfer NSString*)CFURLGetString(url);
        }
        CFRelease(urlRef);
    }
    
    // Get placeholder text (for input fields)
    CFTypeRef placeholderRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXPlaceholderValue"), &placeholderRef) == kAXErrorSuccess && placeholderRef) {
        info[@"placeholder"] = (__bridge_transfer NSString*)placeholderRef;
    }
    
    // Get required state
    CFTypeRef requiredRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXRequired"), &requiredRef) == kAXErrorSuccess && requiredRef) {
        info[@"required"] = (__bridge NSNumber*)requiredRef;
        CFRelease(requiredRef);
    }
    
    // Get invalid state (for form validation)
    CFTypeRef invalidRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXInvalid"), &invalidRef) == kAXErrorSuccess && invalidRef) {
        info[@"invalid"] = (__bridge_transfer NSString*)invalidRef;
    }
    
    // Get expanded state (for dropdowns, accordions)
    CFTypeRef expandedRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXExpanded"), &expandedRef) == kAXErrorSuccess && expandedRef) {
        info[@"expanded"] = (__bridge NSNumber*)expandedRef;
        CFRelease(expandedRef);
    }
    
    // Get selected state
    CFTypeRef selectedRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXSelectedAttribute, &selectedRef) == kAXErrorSuccess && selectedRef) {
        info[@"selected"] = (__bridge NSNumber*)selectedRef;
        CFRelease(selectedRef);
    }
    
    // Get checked state (for checkboxes/radio)
    CFTypeRef checkedRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXValue"), &checkedRef) == kAXErrorSuccess && checkedRef) {
        if (CFGetTypeID(checkedRef) == CFBooleanGetTypeID() || CFGetTypeID(checkedRef) == CFNumberGetTypeID()) {
            info[@"checked"] = (__bridge NSNumber*)checkedRef;
        }
        CFRelease(checkedRef);
    }
    
    // Get enabled state
    CFTypeRef enabledRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXEnabledAttribute, &enabledRef) == kAXErrorSuccess && enabledRef) {
        info[@"enabled"] = (__bridge NSNumber*)enabledRef;
        CFRelease(enabledRef);
    }
    
    // Get visited state (for links)
    CFTypeRef visitedRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXVisited"), &visitedRef) == kAXErrorSuccess && visitedRef) {
        info[@"visited"] = (__bridge NSNumber*)visitedRef;
        CFRelease(visitedRef);
    }
    
    // Get autocomplete attribute
    CFTypeRef autocompleteRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXAutocompleteValue"), &autocompleteRef) == kAXErrorSuccess && autocompleteRef) {
        info[@"autocomplete"] = (__bridge_transfer NSString*)autocompleteRef;
    }
    
    // Get has popup (for menus, dialogs)
    CFTypeRef hasPopupRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXHasPopup"), &hasPopupRef) == kAXErrorSuccess && hasPopupRef) {
        info[@"hasPopup"] = (__bridge NSNumber*)hasPopupRef;
        CFRelease(hasPopupRef);
    }
    
    // Get live region attributes
    CFTypeRef liveRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXARIALive"), &liveRef) == kAXErrorSuccess && liveRef) {
        info[@"ariaLive"] = (__bridge_transfer NSString*)liveRef;
    }
    
    CFTypeRef atomicRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXARIAAtomic"), &atomicRef) == kAXErrorSuccess && atomicRef) {
        info[@"ariaAtomic"] = (__bridge NSNumber*)atomicRef;
        CFRelease(atomicRef);
    }
    
    CFTypeRef busyRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, CFSTR("AXARIABusy"), &busyRef) == kAXErrorSuccess && busyRef) {
        info[@"ariaBusy"] = (__bridge NSNumber*)busyRef;
        CFRelease(busyRef);
    }
    
    // Get position and size
    CFTypeRef posRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXPositionAttribute, &posRef) == kAXErrorSuccess && posRef) {
        CGPoint pos;
        if (AXValueGetValue(posRef, kAXValueCGPointType, &pos)) {
            info[@"boundsX"] = @(pos.x);
            info[@"boundsY"] = @(pos.y);
        }
        CFRelease(posRef);
    }
    
    CFTypeRef sizeRef = NULL;
    if (AXUIElementCopyAttributeValue(focusedElement, kAXSizeAttribute, &sizeRef) == kAXErrorSuccess && sizeRef) {
        CGSize size;
        if (AXValueGetValue(sizeRef, kAXValueCGSizeType, &size)) {
            info[@"boundsWidth"] = @(size.width);
            info[@"boundsHeight"] = @(size.height);
        }
        CFRelease(sizeRef);
    }
    
    // Add application info
    info[@"applicationName"] = frontApp.localizedName ?: @"Unknown";
    info[@"pid"] = @(frontApp.processIdentifier);
    
    // For browser elements, try to get parent document URL by traversing up the tree
    NSString* appName = frontApp.localizedName;
    if ([appName containsString:@"Safari"] || [appName containsString:@"Chrome"] || 
        [appName containsString:@"Firefox"] || [appName containsString:@"Edge"]) {
        
        // Traverse up to find the web area or window with URL
        AXUIElementRef parent = focusedElement;
        CFRetain(parent); // Keep reference for traversal
        
        for (int i = 0; i < 20; i++) { // Max 20 levels up
            AXUIElementRef nextParent = NULL;
            if (AXUIElementCopyAttributeValue(parent, kAXParentAttribute, (CFTypeRef*)&nextParent) == kAXErrorSuccess && nextParent) {
                
                // Check for document URL at this level
                CFTypeRef docUrlRef = NULL;
                if (AXUIElementCopyAttributeValue(nextParent, kAXURLAttribute, &docUrlRef) == kAXErrorSuccess && docUrlRef) {
                    if (CFGetTypeID(docUrlRef) == CFURLGetTypeID()) {
                        CFURLRef docUrl = (CFURLRef)docUrlRef;
                        NSString* urlString = (__bridge NSString*)CFURLGetString(docUrl);
                        if (urlString && [urlString hasPrefix:@"http"]) {
                            info[@"documentURL"] = urlString;
                        }
                    }
                    CFRelease(docUrlRef);
                }
                
                // Check role - stop at web area or window
                CFTypeRef parentRoleRef = NULL;
                if (AXUIElementCopyAttributeValue(nextParent, kAXRoleAttribute, &parentRoleRef) == kAXErrorSuccess && parentRoleRef) {
                    NSString* parentRole = (__bridge NSString*)parentRoleRef;
                    CFRelease(parentRoleRef);
                    
                    if ([parentRole isEqualToString:@"AXWebArea"]) {
                        // Get document title from web area
                        CFTypeRef webTitleRef = NULL;
                        if (AXUIElementCopyAttributeValue(nextParent, kAXTitleAttribute, &webTitleRef) == kAXErrorSuccess && webTitleRef) {
                            info[@"documentTitle"] = (__bridge_transfer NSString*)webTitleRef;
                        }
                        
                        CFRelease(nextParent);
                        break;
                    }
                    
                    if ([parentRole isEqualToString:@"AXWindow"]) {
                        // Get window title
                        CFTypeRef winTitleRef = NULL;
                        if (AXUIElementCopyAttributeValue(nextParent, kAXTitleAttribute, &winTitleRef) == kAXErrorSuccess && winTitleRef) {
                            NSString* winTitle = (__bridge_transfer NSString*)winTitleRef;
                            if (!info[@"documentTitle"]) {
                                info[@"documentTitle"] = winTitle;
                            }
                        }
                        
                        CFRelease(nextParent);
                        break;
                    }
                }
                
                CFRelease(parent);
                parent = nextParent;
            } else {
                break;
            }
        }
        
        if (parent != focusedElement) {
            CFRelease(parent);
        }
    }
    
    CFRelease(focusedElement);
    
    if (info[@"role"] || info[@"title"] || info[@"label"]) {
        return info;
    }
    
    return nil;
}

// Create a signature string for a focused element to detect duplicates
NSString* createFocusSignature(NSDictionary* element) {
    if (!element) return @"";
    // Use stable identifiers only - bounds can shift slightly
    return [NSString stringWithFormat:@"%@|%@|%@|%@|%@",
            element[@"role"] ?: @"",
            element[@"title"] ?: @"",
            element[@"label"] ?: @"",
            element[@"domId"] ?: @"",
            element[@"applicationName"] ?: @""];
}

// Check if focus changed to a different element (returns YES if different)
BOOL isFocusDifferent(NSDictionary* newElement) {
    NSString* newSignature = createFocusSignature(newElement);
    if ([newSignature isEqualToString:lastFocusedElementSignature ?: @""]) {
        return NO; // Same element, suppress duplicate
    }
    lastFocusedElementSignature = [newSignature copy];
    return YES; // Different element
}

// Check if element has an interactive role worth tracking focus for
BOOL isInteractiveRole(NSString* role) {
    if (!role) return NO;
    return ([role isEqualToString:@"AXButton"] ||
            [role isEqualToString:@"AXLink"] ||
            [role isEqualToString:@"AXTextField"] ||
            [role isEqualToString:@"AXTextArea"] ||
            [role isEqualToString:@"AXCheckBox"] ||
            [role isEqualToString:@"AXRadioButton"] ||
            [role isEqualToString:@"AXPopUpButton"] ||
            [role isEqualToString:@"AXComboBox"] ||
            [role isEqualToString:@"AXSlider"] ||
            [role isEqualToString:@"AXTabGroup"] ||
            [role isEqualToString:@"AXTab"] ||
            [role isEqualToString:@"AXMenuItem"] ||
            [role isEqualToString:@"AXMenuButton"] ||
            [role isEqualToString:@"AXDisclosureTriangle"] ||
            [role isEqualToString:@"AXIncrementor"] ||
            [role isEqualToString:@"AXColorWell"] ||
            [role isEqualToString:@"AXWebArea"] ||
            [role isEqualToString:@"AXGroup"] ||
            [role isEqualToString:@"AXDialog"] ||
            [role isEqualToString:@"AXSheet"] ||
            [role isEqualToString:@"AXWindow"]);
}

// Emit focus_change event if focus moved to a new interactive element, or focus_lost if no focus
void emitFocusChangeIfNeeded(NSString* trigger, CGFloat x, CGFloat y, CGEventTimestamp timestamp) {
    NSDictionary* focusedElement = getFocusedElement();
    
    if (focusedElement) {
        if (isFocusDifferent(focusedElement)) {
            NSString* role = focusedElement[@"role"];
            if (isInteractiveRole(role)) {
                NSMutableDictionary* focusEventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"trigger": trigger,
                    @"x": @(x),
                    @"y": @(y),
                    @"systemTimestamp": @(timestamp)
                }];
                focusEventData[@"focusedElement"] = focusedElement;
                outputEvent(@"focus_change", focusEventData);
            }
        }
    } else {
        // No element has focus - emit focus_lost if we previously had focus
        if (lastFocusedElementSignature && ![lastFocusedElementSignature isEqualToString:@""]) {
            lastFocusedElementSignature = @"";
            outputEvent(@"focus_lost", @{
                @"trigger": trigger,
                @"x": @(x),
                @"y": @(y),
                @"systemTimestamp": @(timestamp)
            });
        }
    }
}

// Schedule delayed focus checks for programmatic focus changes (modals, skip links)
void scheduleDelayedFocusCheck(CGFloat x, CGFloat y, CGEventTimestamp timestamp) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        emitFocusChangeIfNeeded(@"programmatic", x, y, timestamp);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        emitFocusChangeIfNeeded(@"programmatic", x, y, timestamp);
    });
}

// Convert key codes to readable key names
NSString* keyCodeToString(CGKeyCode keyCode) {
    switch (keyCode) {
        case kVK_Return: return @"Return";
        case kVK_Tab: return @"Tab";
        case kVK_Space: return @"Space";
        case kVK_Delete: return @"Delete";
        case kVK_Escape: return @"Escape";
        case kVK_Command: return @"Command";
        case kVK_Shift: return @"Shift";
        case kVK_CapsLock: return @"CapsLock";
        case kVK_Option: return @"Option";
        case kVK_Control: return @"Control";
        case kVK_RightShift: return @"RightShift";
        case kVK_RightOption: return @"RightOption";
        case kVK_RightControl: return @"RightControl";
        case kVK_Function: return @"Function";
        case kVK_F1: return @"F1";
        case kVK_F2: return @"F2";
        case kVK_F3: return @"F3";
        case kVK_F4: return @"F4";
        case kVK_F5: return @"F5";
        case kVK_F6: return @"F6";
        case kVK_F7: return @"F7";
        case kVK_F8: return @"F8";
        case kVK_F9: return @"F9";
        case kVK_F10: return @"F10";
        case kVK_F11: return @"F11";
        case kVK_F12: return @"F12";
        case kVK_UpArrow: return @"ArrowUp";
        case kVK_DownArrow: return @"ArrowDown";
        case kVK_LeftArrow: return @"ArrowLeft";
        case kVK_RightArrow: return @"ArrowRight";
        case kVK_Home: return @"Home";
        case kVK_End: return @"End";
        case kVK_PageUp: return @"PageUp";
        case kVK_PageDown: return @"PageDown";
        default:
            // For regular keys, try to get the character
            if (keyCode >= kVK_ANSI_A && keyCode <= kVK_ANSI_Z) {
                return [NSString stringWithFormat:@"%c", 'A' + (keyCode - kVK_ANSI_A)];
            }
            if (keyCode >= kVK_ANSI_0 && keyCode <= kVK_ANSI_9) {
                return [NSString stringWithFormat:@"%c", '0' + (keyCode - kVK_ANSI_0)];
            }
            return [NSString stringWithFormat:@"Key%d", keyCode];
    }
}

// Get modifier flags as array
NSArray* getModifierFlags(CGEventFlags flags) {
    NSMutableArray* modifiers = [NSMutableArray array];
    
    if (flags & kCGEventFlagMaskCommand) [modifiers addObject:@"Command"];
    if (flags & kCGEventFlagMaskShift) [modifiers addObject:@"Shift"];
    if (flags & kCGEventFlagMaskAlternate) [modifiers addObject:@"Option"];
    if (flags & kCGEventFlagMaskControl) [modifiers addObject:@"Control"];
    if (flags & kCGEventFlagMaskNumericPad) [modifiers addObject:@"NumPad"];
    if (flags & kCGEventFlagMaskHelp) [modifiers addObject:@"Help"];
    if (flags & kCGEventFlagMaskAlphaShift) [modifiers addObject:@"CapsLock"];
    
    return [modifiers copy];
}

// Output JSON event to stdout for Node.js to consume
void outputEvent(NSString* eventType, NSDictionary* eventData) {
    @autoreleasepool {
        NSError* error = nil;
        
        NSDictionary* eventDict = @{
            @"type": eventType,
            @"timestamp": @((uint64_t)([[NSDate date] timeIntervalSince1970] * 1000000)), // microseconds
            @"data": eventData ?: @{}
        };
        
        NSData* jsonData = [NSJSONSerialization dataWithJSONObject:eventDict 
                                                           options:NSJSONWritingPrettyPrinted 
                                                             error:&error];
        
        if (error) {
            fprintf(stderr, "JSON serialization error: %s\n", [[error localizedDescription] UTF8String]);
            fflush(stderr);
            return;
        }
        
        if (!jsonData) {
            fprintf(stderr, "No JSON data created\n");
            fflush(stderr);
            return;
        }
        
        NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        if (!jsonString) {
            fprintf(stderr, "Failed to create JSON string\n");
            fflush(stderr);
            return;
        }
        
        // Remove pretty printing newlines for single line output
        NSString* compactJson = [jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
        compactJson = [compactJson stringByReplacingOccurrencesOfString:@"  " withString:@""];
        
        printf("%s\n", [compactJson UTF8String]);
        fflush(stdout);
    }
}

// Main event callback  
CGEventRef eventCallback(CGEventTapProxy proxy __unused, CGEventType type, CGEventRef event, void *userInfo __unused) {
    @autoreleasepool {
        // Filter out system-generated events - only capture real user interactions
        CGEventFlags flags = CGEventGetFlags(event);
        CGEventSourceRef source = CGEventCreateSourceFromEvent(event);
        CGEventSourceStateID sourceState = CGEventSourceGetSourceStateID(source);
        
        // Skip events that are not from hardware (programmatic/system events)
        if (sourceState != kCGEventSourceStateHIDSystemState && sourceState != kCGEventSourceStateCombinedSessionState) {
            if (source) CFRelease(source);
            return event;  // Pass through but don't capture
        }
        
        // Also check if this is a synthetic event (programmatically generated)
        if (flags & kCGEventFlagMaskSecondaryFn) {
            if (source) CFRelease(source);
            return event;  // Skip synthetic events
        }
        
        if (source) CFRelease(source);
        
        CGPoint location = CGEventGetLocation(event);
        CGEventTimestamp timestamp = CGEventGetTimestamp(event);
        
        // Add debug info about the event source
        bool isUserEvent = (sourceState == kCGEventSourceStateHIDSystemState || sourceState == kCGEventSourceStateCombinedSessionState);
        
        switch (type) {
            case kCGEventLeftMouseDown: {
                int64_t clickCount = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
                NSArray* modifiers = getModifierFlags(flags);
                
                // Get accessibility element info at click location
                NSDictionary* elementInfo = getElementAtPoint(location.x, location.y);
                
                NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"button": @"left",
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @(clickCount),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp),
                    @"sourceState": @(sourceState),
                    @"isUserEvent": @(isUserEvent),
                    @"flags": @(flags)
                }];
                
                if (elementInfo) {
                    eventData[@"element"] = elementInfo;
                }
                
                outputEvent(@"mouse_down", eventData);
                break;
            }
                
            case kCGEventLeftMouseUp: {
                int64_t clickCount = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
                NSArray* modifiers = getModifierFlags(flags);
                
                // Get accessibility element info at click location
                NSDictionary* elementInfo = getElementAtPoint(location.x, location.y);
                
                NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"button": @"left",
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @(clickCount),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                }];
                
                if (elementInfo) {
                    eventData[@"element"] = elementInfo;
                }
                
                outputEvent(@"mouse_up", eventData);
                
                // Check for immediate focus change (clicking on focusable elements)
                emitFocusChangeIfNeeded(@"click", location.x, location.y, timestamp);
                
                // Schedule delayed checks for programmatic focus changes (modals, skip links)
                scheduleDelayedFocusCheck(location.x, location.y, timestamp);
                break;
            }
                
            case kCGEventRightMouseDown: {
                int64_t clickCount = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
                NSArray* modifiers = getModifierFlags(flags);
                
                NSDictionary* elementInfo = getElementAtPoint(location.x, location.y);
                
                NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"button": @"right", 
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @(clickCount),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                }];
                
                if (elementInfo) {
                    eventData[@"element"] = elementInfo;
                }
                
                outputEvent(@"mouse_down", eventData);
                break;
            }
                
            case kCGEventRightMouseUp: {
                int64_t clickCount = CGEventGetIntegerValueField(event, kCGMouseEventClickState);
                NSArray* modifiers = getModifierFlags(flags);
                
                NSDictionary* elementInfo = getElementAtPoint(location.x, location.y);
                
                NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"button": @"right", 
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @(clickCount),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                }];
                
                if (elementInfo) {
                    eventData[@"element"] = elementInfo;
                }
                
                outputEvent(@"mouse_up", eventData);
                break;
            }
                
            case kCGEventOtherMouseDown: {
                int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
                NSString* buttonName = (buttonNumber == 2) ? @"middle" : [NSString stringWithFormat:@"button%lld", buttonNumber];
                NSArray* modifiers = getModifierFlags(flags);
                outputEvent(@"mouse_down", @{
                    @"button": buttonName,
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @1,
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                });
                break;
            }
                
            case kCGEventOtherMouseUp: {
                int64_t buttonNumber = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
                NSString* buttonName = (buttonNumber == 2) ? @"middle" : [NSString stringWithFormat:@"button%lld", buttonNumber];
                NSArray* modifiers = getModifierFlags(flags);
                outputEvent(@"mouse_up", @{
                    @"button": buttonName,
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"clickCount": @1,
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                });
                break;
            }
                
            case kCGEventScrollWheel: {
                int64_t deltaY = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis1);
                int64_t deltaX = CGEventGetIntegerValueField(event, kCGScrollWheelEventDeltaAxis2);
                NSArray* modifiers = getModifierFlags(flags);
                outputEvent(@"scroll", @{
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"deltaX": @(deltaX),
                    @"deltaY": @(deltaY),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                });
                break;
            }
                
            case kCGEventKeyDown: {
                CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
                CGEventFlags flags = CGEventGetFlags(event);
                
                // Skip if it's just a modifier key press by itself
                if (keyCode == kVK_Command || keyCode == kVK_Shift || 
                    keyCode == kVK_Option || keyCode == kVK_Control ||
                    keyCode == kVK_RightCommand || keyCode == kVK_RightShift ||
                    keyCode == kVK_RightOption || keyCode == kVK_RightControl) {
                    break;
                }
                
                NSString* keyName = keyCodeToString(keyCode);
                NSArray* modifiers = getModifierFlags(flags);
                
                NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                    @"key": keyName,
                    @"keyCode": @(keyCode),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                }];
                
                // Emit key_press for all keys including Tab (the user action)
                outputEvent(@"key_press", eventData);
                break;
            }
            
            case kCGEventKeyUp: {
                CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
                CGEventFlags flags = CGEventGetFlags(event);
                
                // On Tab key up, emit focus_change with the newly focused element
                // This comes after the key_press event, showing the result of tabbing
                if (keyCode == kVK_Tab) {
                    NSArray* modifiers = getModifierFlags(flags);
                    
                    // Get the now-focused element (focus has moved after Tab was processed)
                    NSDictionary* focusedElement = getFocusedElement();
                    
                    // Only emit if focus actually changed to a different element
                    if (isFocusDifferent(focusedElement)) {
                        NSMutableDictionary* eventData = [NSMutableDictionary dictionaryWithDictionary:@{
                            @"key": @"Tab",
                            @"keyCode": @(keyCode),
                            @"modifiers": modifiers,
                            @"systemTimestamp": @(timestamp)
                        }];
                        
                        if (focusedElement) {
                            eventData[@"focusedElement"] = focusedElement;
                        }
                        
                        outputEvent(@"focus_change", eventData);
                    }
                }
                break;
            }
                
            case kCGEventMouseMoved: {
                // Only output mouse moves occasionally to avoid spam
                static NSDate* lastMouseMoveTime = nil;
                NSDate* now = [NSDate date];
                if (!lastMouseMoveTime || [now timeIntervalSinceDate:lastMouseMoveTime] > 0.1) { // 100ms throttle
                    outputEvent(@"mouse_move", @{
                        @"x": @(location.x),
                        @"y": @(location.y),
                        @"systemTimestamp": @(timestamp)
                    });
                    lastMouseMoveTime = now;
                }
                break;
            }
                
            case kCGEventLeftMouseDragged:
            case kCGEventRightMouseDragged:
            case kCGEventOtherMouseDragged: {
                NSString* button = (type == kCGEventLeftMouseDragged) ? @"left" : 
                                  (type == kCGEventRightMouseDragged) ? @"right" : @"other";
                NSArray* modifiers = getModifierFlags(flags);
                outputEvent(@"mouse_drag", @{
                    @"button": button,
                    @"x": @(location.x),
                    @"y": @(location.y),
                    @"modifiers": modifiers,
                    @"systemTimestamp": @(timestamp)
                });
                break;
            }
                
            default:
                // Ignore other event types
                break;
        }
    }
    
    // Always return the event unmodified (we're just listening)
    return event;
}

// Signal handler for clean shutdown
void signalHandler(int signal __unused) {
    outputEvent(@"system", @{@"message": @"Shutting down event capture"});
    shouldContinue = false;
    CFRunLoopStop(CFRunLoopGetCurrent());
}

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        // Set up signal handlers for clean shutdown
        signal(SIGINT, signalHandler);
        signal(SIGTERM, signalHandler);
        
        // Output startup message
        outputEvent(@"system", @{@"message": @"Starting native event capture"});
        
        // Define which events we want to capture
        CGEventMask eventMask = 
            CGEventMaskBit(kCGEventLeftMouseDown) |
            CGEventMaskBit(kCGEventLeftMouseUp) |
            CGEventMaskBit(kCGEventRightMouseDown) |
            CGEventMaskBit(kCGEventRightMouseUp) |
            CGEventMaskBit(kCGEventOtherMouseDown) |
            CGEventMaskBit(kCGEventOtherMouseUp) |
            CGEventMaskBit(kCGEventScrollWheel) |
            CGEventMaskBit(kCGEventKeyDown) |
            CGEventMaskBit(kCGEventKeyUp) |
            CGEventMaskBit(kCGEventMouseMoved) |
            CGEventMaskBit(kCGEventLeftMouseDragged) |
            CGEventMaskBit(kCGEventRightMouseDragged) |
            CGEventMaskBit(kCGEventOtherMouseDragged);
        
        // Create the event tap
        CFMachPortRef eventTap = CGEventTapCreate(
            kCGSessionEventTap,           // Session-level tap (works with public APIs)
            kCGHeadInsertEventTap,        // Insert at head of queue
            kCGEventTapOptionListenOnly,  // Listen only, don't modify events  
            eventMask,                    // Events we want to capture
            eventCallback,                // Our callback function
            NULL                          // No user data
        );
        
        if (!eventTap) {
            fprintf(stderr, "ERROR: Failed to create event tap.\n");
            fprintf(stderr, "Make sure this app has Accessibility permissions:\n");
            fprintf(stderr, "System Preferences → Security & Privacy → Privacy → Accessibility\n");
            outputEvent(@"error", @{@"message": @"Failed to create event tap - check Accessibility permissions"});
            return 1;
        }
        
        // Create run loop source
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        if (!runLoopSource) {
            fprintf(stderr, "ERROR: Failed to create run loop source.\n");
            CFRelease(eventTap);
            return 1;
        }
        
        // Add source to current run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        
        // Enable the event tap
        CGEventTapEnable(eventTap, true);
        
        // Output ready message
        outputEvent(@"system", @{@"message": @"Event capture ready - listening for events"});
        
        // Run the event loop
        while (shouldContinue) {
            CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
        }
        
        // Cleanup
        CGEventTapEnable(eventTap, false);
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        CFRelease(eventTap);
        
        outputEvent(@"system", @{@"message": @"Event capture stopped"});
    }
    
    return 0;
}