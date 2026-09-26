import SwiftUI

// Window delegate to handle window closing
class WindowDelegate: NSObject, NSWindowDelegate {
  let spaceStation: SpaceStation

  init(spaceStation: SpaceStation) {
    self.spaceStation = spaceStation
    super.init()
  }
}

// Window controller for the floating window
class FloatingWindowController {
  private var window: NSWindow?
  private var windowDelegate: WindowDelegate?

  func showWindow(with rootView: some View, spaceStation: SpaceStation) {
    let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

    if let window = window {
      // Resize and re-center to match the current screen every time the window is shown,
      // so that resolution or display changes (e.g. switching monitors) are picked up.
      window.setFrame(frame, display: false)
      window.center()
      window.orderFront(nil)
      return
    }

    // Create the window
    let window = NSWindow(
      contentRect: frame,
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    // Configure window properties
    window.center()
    window.isReleasedWhenClosed = false
    window.level = .floating  // This makes it stay on top of other windows
    window.backgroundColor = .clear
    window.isOpaque = false
    window.hasShadow = false

    // Set window content
    let hostingView = NSHostingView(rootView: rootView.environmentObject(spaceStation))
    window.contentView = hostingView

    // Set up window delegate
    windowDelegate = WindowDelegate(spaceStation: spaceStation)
    window.delegate = windowDelegate

    self.window = window
    window.makeKeyAndOrderFront(nil)
  }

  func hideWindow() {
    window?.orderOut(nil)
  }
}
