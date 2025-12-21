# TrackerA11y Safari Extension

This Safari Web Extension captures detailed DOM information when elements receive focus.

## Installation

### Option 1: Convert to Safari Extension (Recommended)

1. Open Terminal and run:
   ```bash
   xcrun safari-web-extension-converter /Users/bob3/Desktop/trackerA11y/SafariExtension/TrackerA11yExtension --app-name "TrackerA11y Extension" --bundle-identifier com.trackera11y.extension --project-location /Users/bob3/Desktop/trackerA11y/SafariExtension/XcodeProject
   ```

2. Open the generated Xcode project
3. Sign with your Developer ID
4. Build and run
5. Enable the extension in Safari > Settings > Extensions

### Option 2: Developer Mode

1. Safari > Settings > Advanced > Show Develop menu
2. Develop > Allow Unsigned Extensions
3. Safari > Settings > Extensions > Enable TrackerA11y

## Native Messaging Setup

For the extension to communicate with TrackerA11y app, add to Info.plist of main app:

```xml
<key>NSExtensionPointIdentifier</key>
<string>com.apple.Safari.web-extension</string>
```

And create a native messaging manifest at:
`~/Library/Application Support/TrackerA11y/NativeMessagingHosts/com.trackera11y.app.json`

```json
{
  "name": "com.trackera11y.app",
  "description": "TrackerA11y Native Messaging Host",
  "path": "/Applications/TrackerA11yApp.app/Contents/MacOS/TrackerA11yApp",
  "type": "stdio",
  "allowed_extensions": ["com.trackera11y.extension"]
}
```

## What it Captures

For each focused element:
- Tag name, ID, classes
- All HTML attributes
- All ARIA attributes
- Computed CSS styles
- XPath
- Outer HTML
- Bounding rect (viewport and screen coordinates)
- Parent URL and title
- Form-related properties
- State (disabled, checked, required, etc.)
