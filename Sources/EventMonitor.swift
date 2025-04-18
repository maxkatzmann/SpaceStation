import AppKit
import SwiftUI

@Observable
class EventMonitor {
  var code: String = "0"

  init() {
    NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] (event) in
      self?.code = "\(event.keyCode)"
    }
  }
}
