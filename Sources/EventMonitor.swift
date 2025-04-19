import AppKit
import SwiftUI
import Swindler

@Observable
class EventMonitor {
  var events: Int = 0

  private var optionDown: Bool = false {
    didSet {
      guard self.optionDown != oldValue else {
        return
      }

      self.events += 1
    }
  }

  private var swindler: Swindler.State!

  init() {
    self.setupModifierEventMonitor()
    self.setupWindowEventMonitor()
  }

  func setupModifierEventMonitor() {
    NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) {
      [weak self] (event) in
      self?.optionDown = NSEvent.modifierFlags.contains(.option)
    }
  }

  func setupWindowEventMonitor() {
    Swindler.initialize().done { state in
      self.swindler = state

      self.swindler.on { (event: FrontmostApplicationChangedEvent) in
        self.events += 1
      }

      self.swindler.on { (event: ApplicationFocusedWindowChangedEvent) in
        self.events += 1
      }

    }.catch { error in
      print(
        "Fatal error: failed to initialize Swindler: \(String(describing: error))")
      NSApp.terminate(self)
    }
  }

  // TODO: Included timed action to update option state every x milliseconds as long as optionIsDown
}
