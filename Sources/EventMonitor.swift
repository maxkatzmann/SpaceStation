import AppKit
import Combine
import SwiftUI

class EventMonitor: ObservableObject {
  @Published var code: String = "0"

  init() {
    NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] (event) in
      self?.code = "\(event.keyCode)"
    }
  }
}
