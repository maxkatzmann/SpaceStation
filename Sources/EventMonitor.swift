import AppKit
import SwiftUI

@Observable
class EventMonitor {
  var code: String = "0"
  var optionDown: Bool = false

  init() {
    NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) {
      [weak self] (event) in
      self?.code = "\(event.keyCode)"
      self?.optionDown = NSEvent.modifierFlags.contains(.option)
    }
  }

  // TODO: Included timed action to update option state every x milliseconds as long as optionIsDown
}
