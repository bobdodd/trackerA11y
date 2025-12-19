import Cocoa

// Custom main function to avoid NSApplicationMain and storyboard dependency
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()