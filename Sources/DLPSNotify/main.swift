import AppKit

// Menu bar agent: no Dock icon, no main window.
let delegate = AppDelegate()
let application = NSApplication.shared
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
