import SwiftUI

@Observable
class SpaceStation {
  private let eventMonitor = EventMonitor()

  var spaces: [Int] = []

  init() {
    self.eventMonitor.delgate = self
  }
}

extension SpaceStation: EventMonitorDelegate {
  func didObserveEvent() {
    self.spaces = [(self.spaces.first ?? 0) + 1]
  }
}
