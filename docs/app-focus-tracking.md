# Application Focus Tracking Research

## Overview

This document contains comprehensive technical research on application focus tracking methods across different platforms for accessibility testing. The goal is to monitor which application has focus (typically browsers on desktop, native apps on mobile) and track its lifecycle.

## Platform-Specific APIs

### Windows Platform

#### Primary APIs
- `GetForegroundWindow()` - Returns handle to the foreground window
- `GetActiveWindow()` - Returns active window for current thread
- `GetFocus()` - Returns window with keyboard focus

#### Implementation Example

```cpp
#include <windows.h>
#include <psapi.h>

HWND GetCurrentFocusedWindow() {
    return GetForegroundWindow();
}

std::string GetApplicationName(HWND hwnd) {
    DWORD processId;
    GetWindowThreadProcessId(hwnd, &processId);
    
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
    if (hProcess) {
        char processName[MAX_PATH];
        if (GetModuleBaseNameA(hProcess, NULL, processName, MAX_PATH)) {
            CloseHandle(hProcess);
            return std::string(processName);
        }
        CloseHandle(hProcess);
    }
    return "";
}
```

#### Event-Driven Monitoring

```cpp
// Hook for window focus changes
HWINEVENTHOOK hWinEventHook = SetWinEventHook(
    EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND,
    NULL, WinEventProc, 0, 0,
    WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);

void CALLBACK WinEventProc(HWINEVENTHOOK hWinEventHook, DWORD event,
    HWND hwnd, LONG idObject, LONG idChild, DWORD dwEventThread, DWORD dwmsEventTime) {
    if (event == EVENT_SYSTEM_FOREGROUND) {
        // Handle focus change
        std::cout << "Focus changed to: " << GetApplicationName(hwnd) << std::endl;
    }
}
```

### macOS Platform

#### Primary APIs
- `NSWorkspace.shared.frontmostApplication` - Current active application
- `NSAccessibility.accessibilityApplicationFocusedUIElement` - Focused UI element

#### Swift Implementation

```swift
import Cocoa
import ApplicationServices

class FocusTracker {
    private var workspace: NSWorkspace
    private var currentApp: NSRunningApplication?
    
    init() {
        workspace = NSWorkspace.shared
        startMonitoring()
    }
    
    func startMonitoring() {
        // Monitor application activation
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appDidActivate),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }
    
    @objc func appDidActivate(notification: NSNotification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            currentApp = app
            print("Focus changed to: \(app.localizedName ?? "Unknown")")
            
            // Get accessibility information
            let focusedElement = NSAccessibility.applicationFocusedUIElement(for: app.processIdentifier)
            // Process accessibility tree...
        }
    }
    
    func getCurrentFocusedApp() -> String? {
        return workspace.frontmostApplication?.localizedName
    }
}
```

#### Objective-C Alternative

```objc
#import <AppKit/AppKit.h>

NSRunningApplication *frontmostApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
NSString *appName = [frontmostApp localizedName];

// Monitor focus changes
[[[NSWorkspace sharedWorkspace] notificationCenter] 
    addObserver:self 
    selector:@selector(activeAppDidChange:) 
    name:NSWorkspaceDidActivateApplicationNotification 
    object:nil];
```

### Linux Platform (X11 and Wayland)

#### X11 Implementation

```c
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>

Window GetActiveWindow(Display *display) {
    Atom activeWindow = XInternAtom(display, "_NET_ACTIVE_WINDOW", False);
    Atom actualType;
    int format;
    unsigned long numItems, bytesAfter;
    unsigned char *data = NULL;
    
    int status = XGetWindowProperty(display, DefaultRootWindow(display),
        activeWindow, 0L, (~0L), False, AnyPropertyType,
        &actualType, &format, &numItems, &bytesAfter, &data);
    
    if (status == Success && data) {
        Window activeWin = ((unsigned long*)data)[0];
        XFree(data);
        return activeWin;
    }
    return 0;
}

char* GetWindowTitle(Display *display, Window window) {
    char *title = NULL;
    if (XFetchName(display, window, &title) && title) {
        return title;
    }
    return NULL;
}
```

#### Wayland/D-Bus Implementation

```python
import dbus
from gi.repository import GLib
import gi
gi.require_version('Atspi', '2.0')
from gi.repository import Atspi

class WaylandFocusTracker:
    def __init__(self):
        self.bus = dbus.SessionBus()
        Atspi.init()
        
    def get_focused_application(self):
        desktop = Atspi.get_desktop(0)
        for app in desktop:
            if app and app.get_state_set().contains(Atspi.StateType.ACTIVE):
                return app.get_name()
        return None
    
    def monitor_focus_changes(self):
        # Use AT-SPI event monitoring
        Atspi.EventListener.new(self._on_focus_change, None)
        
    def _on_focus_change(self, event, user_data):
        if event.type.startswith("focus"):
            app_name = event.source.get_application().get_name()
            print(f"Focus changed to: {app_name}")
```

### iOS Platform

#### UIKit Implementation

```swift
import UIKit
import AccessibilityServices

class iOSFocusTracker {
    private var currentState: UIApplication.State = .active
    
    func startMonitoring() {
        // Monitor application state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc func appDidBecomeActive() {
        currentState = .active
        trackAccessibilityFocus()
    }
    
    @objc func appDidEnterBackground() {
        currentState = .background
    }
    
    func trackAccessibilityFocus() {
        // Monitor accessibility focus changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accessibilityFocusChanged),
            name: UIAccessibility.elementFocusedNotification,
            object: nil
        )
    }
    
    @objc func accessibilityFocusChanged(notification: NSNotification) {
        if let focusedElement = notification.userInfo?[UIAccessibility.focusedElementUserInfoKey] {
            print("Accessibility focus changed to: \(focusedElement)")
        }
    }
}
```

### Android Platform

#### AccessibilityService Implementation

```java
public class FocusTrackingAccessibilityService extends AccessibilityService {
    
    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        switch (event.getEventType()) {
            case AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED:
                handleWindowStateChange(event);
                break;
            case AccessibilityEvent.TYPE_VIEW_FOCUSED:
                handleViewFocused(event);
                break;
        }
    }
    
    private void handleWindowStateChange(AccessibilityEvent event) {
        CharSequence packageName = event.getPackageName();
        CharSequence className = event.getClassName();
        
        Log.d("FocusTracker", "App focus changed to: " + packageName);
        
        // Get app name from package name
        PackageManager pm = getPackageManager();
        try {
            ApplicationInfo appInfo = pm.getApplicationInfo(packageName.toString(), 0);
            String appName = pm.getApplicationLabel(appInfo).toString();
            Log.d("FocusTracker", "App name: " + appName);
        } catch (PackageManager.NameNotFoundException e) {
            Log.e("FocusTracker", "App not found: " + packageName);
        }
    }
    
    private void handleViewFocused(AccessibilityEvent event) {
        AccessibilityNodeInfo source = event.getSource();
        if (source != null) {
            String text = source.getText() != null ? source.getText().toString() : "";
            String description = source.getContentDescription() != null ? 
                source.getContentDescription().toString() : "";
            
            Log.d("FocusTracker", "Element focused: " + text + " " + description);
        }
    }
    
    @Override
    public void onInterrupt() {
        // Handle interruptions
    }
}
```

## Browser Tab Change Detection

### JavaScript Page Visibility API

```javascript
class BrowserFocusTracker {
    constructor() {
        this.isVisible = !document.hidden;
        this.setupListeners();
    }
    
    setupListeners() {
        // Page Visibility API
        document.addEventListener('visibilitychange', () => {
            this.isVisible = !document.hidden;
            this.handleVisibilityChange();
        });
        
        // Window focus/blur events (fallback)
        window.addEventListener('focus', () => {
            this.handleWindowFocus();
        });
        
        window.addEventListener('blur', () => {
            this.handleWindowBlur();
        });
        
        // Browser tab title changes
        this.observeTitleChanges();
    }
    
    handleVisibilityChange() {
        const timestamp = Date.now();
        const state = this.isVisible ? 'visible' : 'hidden';
        
        console.log(`Tab ${state} at ${timestamp}`);
        
        // Send to tracking system
        this.sendFocusEvent({
            type: 'tab_visibility_change',
            state: state,
            timestamp: timestamp,
            url: window.location.href,
            title: document.title
        });
    }
    
    observeTitleChanges() {
        const observer = new MutationObserver((mutations) => {
            mutations.forEach((mutation) => {
                if (mutation.type === 'childList' && 
                    mutation.target === document.querySelector('title')) {
                    this.handleTitleChange();
                }
            });
        });
        
        const titleElement = document.querySelector('title');
        if (titleElement) {
            observer.observe(titleElement, { childList: true });
        }
    }
    
    sendFocusEvent(eventData) {
        // Send to your accessibility testing platform
        fetch('/api/focus-events', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(eventData)
        });
    }
}

// Initialize tracker
const focusTracker = new BrowserFocusTracker();
```

## Cross-Platform Libraries and Frameworks

### Electron Focus Tracking

```javascript
const { app, BrowserWindow, ipcMain } = require('electron');

class ElectronFocusTracker {
    constructor() {
        this.mainWindow = null;
        this.setupEventListeners();
    }
    
    setupEventListeners() {
        app.on('browser-window-focus', (event, window) => {
            console.log('Electron window gained focus');
            this.trackWindowFocus(window, true);
        });
        
        app.on('browser-window-blur', (event, window) => {
            console.log('Electron window lost focus');
            this.trackWindowFocus(window, false);
        });
        
        // Track web content focus within Electron
        ipcMain.on('web-content-focus', (event, data) => {
            this.trackWebContentFocus(data);
        });
    }
    
    trackWindowFocus(window, hasFocus) {
        const focusData = {
            type: 'electron_window_focus',
            windowId: window.id,
            hasFocus: hasFocus,
            timestamp: Date.now(),
            bounds: window.getBounds()
        };
        
        this.sendToAccessibilityPlatform(focusData);
    }
}
```

### Tauri Focus Tracking (Rust + JavaScript)

```rust
// src-tauri/src/main.rs
use tauri::{Manager, Window};
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
struct FocusEvent {
    window_label: String,
    has_focus: bool,
    timestamp: u64,
}

#[tauri::command]
async fn track_window_focus(window: Window, has_focus: bool) -> Result<(), String> {
    let focus_event = FocusEvent {
        window_label: window.label().to_string(),
        has_focus,
        timestamp: std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64,
    };
    
    // Send to accessibility platform
    window.emit("focus-changed", &focus_event).unwrap();
    Ok(())
}

fn main() {
    tauri::Builder::default()
        .setup(|app| {
            let window = app.get_window("main").unwrap();
            
            // Monitor window focus events
            window.on_window_event(|event| {
                match event {
                    tauri::WindowEvent::Focused(focused) => {
                        println!("Window focus: {}", focused);
                        // Handle focus change
                    }
                    _ => {}
                }
            });
            
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![track_window_focus])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

## Real-Time Monitoring with Performance Optimization

### Event-Driven vs Polling Performance

#### High-Performance Event System

```python
import asyncio
import time
from typing import Dict, Any, Callable
from dataclasses import dataclass

@dataclass
class FocusEvent:
    timestamp: float
    event_type: str
    application: str
    window_title: str
    process_id: int
    accessibility_info: Dict[str, Any]

class PerformantFocusTracker:
    def __init__(self):
        self.event_queue = asyncio.Queue()
        self.event_handlers: Dict[str, Callable] = {}
        self.last_focus_app = None
        self.debounce_time = 0.1  # 100ms debounce
        self.last_event_time = 0
        
    async def start_monitoring(self):
        # Start platform-specific monitoring
        await asyncio.gather(
            self._monitor_system_events(),
            self._process_event_queue(),
            self._monitor_accessibility_tree()
        )
    
    async def _monitor_system_events(self):
        """Platform-specific event monitoring"""
        while True:
            try:
                # Get current focused application
                current_app = await self._get_current_focus()
                
                # Debounce rapid changes
                current_time = time.time()
                if (current_time - self.last_event_time) > self.debounce_time:
                    if current_app != self.last_focus_app:
                        await self._queue_focus_event(current_app)
                        self.last_focus_app = current_app
                        self.last_event_time = current_time
                
                await asyncio.sleep(0.05)  # 50ms polling for responsiveness
                
            except Exception as e:
                print(f"Error in monitoring: {e}")
                await asyncio.sleep(1)
    
    async def _process_event_queue(self):
        """Process events asynchronously for performance"""
        while True:
            try:
                event = await self.event_queue.get()
                await self._handle_focus_event(event)
                self.event_queue.task_done()
            except Exception as e:
                print(f"Error processing event: {e}")
    
    async def _handle_focus_event(self, event: FocusEvent):
        """Handle focus events with accessibility context"""
        # Correlate with accessibility information
        accessibility_data = await self._get_accessibility_context(event)
        event.accessibility_info = accessibility_data
        
        # Send to accessibility testing platform
        await self._send_to_platform(event)
        
        # Trigger any registered handlers
        for handler in self.event_handlers.values():
            try:
                await handler(event)
            except Exception as e:
                print(f"Error in event handler: {e}")
```

## Integration with Accessibility APIs

### Windows UI Automation Integration

```cpp
#include <UIAutomation.h>
#include <comdef.h>

class WindowsAccessibilityIntegration {
private:
    IUIAutomation* pUIAutomation;
    IUIAutomationElement* pFocusedElement;
    
public:
    HRESULT Initialize() {
        return CoCreateInstance(__uuidof(CUIAutomation), NULL, 
            CLSCTX_INPROC_SERVER, __uuidof(IUIAutomation), 
            (void**)&pUIAutomation);
    }
    
    HRESULT GetFocusedElement() {
        if (pFocusedElement) {
            pFocusedElement->Release();
            pFocusedElement = nullptr;
        }
        
        return pUIAutomation->GetFocusedElement(&pFocusedElement);
    }
    
    std::string GetElementInfo() {
        if (!pFocusedElement) return "";
        
        BSTR name, className, automationId;
        CONTROLTYPEID controlType;
        
        pFocusedElement->get_CurrentName(&name);
        pFocusedElement->get_CurrentClassName(&className);
        pFocusedElement->get_CurrentAutomationId(&automationId);
        pFocusedElement->get_CurrentControlType(&controlType);
        
        // Convert to JSON or structured format
        std::string result = "{";
        result += "\"name\":\"" + _bstr_t(name) + "\",";
        result += "\"className\":\"" + _bstr_t(className) + "\",";
        result += "\"automationId\":\"" + _bstr_t(automationId) + "\",";
        result += "\"controlType\":" + std::to_string(controlType);
        result += "}";
        
        SysFreeString(name);
        SysFreeString(className);
        SysFreeString(automationId);
        
        return result;
    }
};
```

## Limitations and Challenges

### Security and Privacy Constraints

**Windows:**
- UIPI (User Interface Privilege Isolation) restrictions
- UAC elevation requirements for some accessibility APIs
- Windows Defender SmartScreen may flag monitoring applications

**macOS:**
- Accessibility permissions required in System Preferences
- Notarization requirements for distribution
- SIP (System Integrity Protection) limitations

**Linux:**
- Wayland security model restricts window access
- Different permissions needed for X11 vs Wayland
- Compositor-specific implementations vary

**Mobile Platforms:**
- iOS: Accessibility services limited to approved use cases
- Android: User must manually enable accessibility services
- Background processing limitations affect monitoring

### Cross-Platform Consistency Issues

```python
class PlatformAbstraction:
    def __init__(self):
        self.platform_handlers = {
            'windows': WindowsFocusHandler(),
            'darwin': MacOSFocusHandler(),
            'linux': LinuxFocusHandler(),
            'ios': IOSFocusHandler(),
            'android': AndroidFocusHandler()
        }
    
    async def get_unified_focus_data(self) -> Dict[str, Any]:
        """Normalize focus data across platforms"""
        handler = self.platform_handlers.get(self._get_platform())
        if not handler:
            raise UnsupportedPlatformError()
        
        raw_data = await handler.get_focus_data()
        
        # Normalize to common format
        return {
            'timestamp': raw_data.get('timestamp'),
            'application_name': raw_data.get('app_name'),
            'window_title': raw_data.get('window_title'),
            'process_id': raw_data.get('pid'),
            'accessibility_role': raw_data.get('a11y_role'),
            'platform_specific': raw_data.get('platform_data', {})
        }
```

## Implementation Recommendations

### Cross-Platform Architecture

1. **Unified Interface**: Common API for all platforms
2. **Event-Driven Design**: React to focus changes rather than polling
3. **Performance Optimization**: Minimize system overhead
4. **Error Handling**: Graceful degradation when APIs unavailable
5. **Privacy Compliance**: Respect user privacy and system security

### Integration Points

1. **TrackerA11y Core**: Main accessibility testing orchestrator
2. **Audio Analysis**: Correlation with integrated diarized audio processing
3. **Screen Recording**: Synchronization with video capture
4. **Interaction Tracking**: Combined focus and user interaction analysis

This comprehensive guide provides the technical foundation for building robust application focus tracking across all major platforms for TrackerA11y.