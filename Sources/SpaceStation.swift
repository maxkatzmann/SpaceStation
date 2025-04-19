import Foundation
import SwiftUI

struct Space {
  let name: String
  let windows: [Window]
  var isFocused: Bool = false
}

// Define a struct to represent window information
struct Window: Codable, Hashable {
  let windowId: Int
  let appBundleId: String
  let workspace: String
  var isFocused: Bool = false

  enum CodingKeys: String, CodingKey {
    case windowId = "window-id"
    case appBundleId = "app-bundle-id"
    case workspace
  }
}

// @Observable
class SpaceStation: ObservableObject {
  private let eventMonitor = EventMonitor()

  @Published var spaces: [Space] = []

  init() {
    self.eventMonitor.delgate = self
  }

  func updateSpaces() {
    guard
      let result = CommandRunner.runAeroSpaceCommand(withArguments: [
        "list-windows",
        "--all",
        "--json",
        "--format",
        "%{window-id} %{app-bundle-id} %{workspace}",
      ])
    else {
      return
    }

    guard let windows = try? JSONDecoder().decode([Window].self, from: result) else {
      return
    }

    self.spaces = Dictionary(grouping: windows, by: { $0.workspace })
      .map {
        spaceIdentifier, windows in
        Space(
          name: spaceIdentifier,
          windows: windows,
          isFocused: false
        )
      }
      .sorted(using: KeyPathComparator(\.name))
  }
}

extension SpaceStation: EventMonitorDelegate {
  func didObserveEvent() {
    self.updateSpaces()
  }
}
