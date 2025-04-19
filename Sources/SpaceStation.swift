import Foundation
import SwiftUI

struct Space {
  let name: String
  var windows: [Window]
  var isFocused: Bool = false
}

// Define a struct to represent window information
struct Window: Codable, Hashable {
  let windowId: Int
  var appBundleId: String
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

    guard var windows = try? JSONDecoder().decode([Window].self, from: result) else {
      return
    }

    // Neovide hack. Currently, neovide does not have an appBundleId for any but the very first window.
    for i in 0..<windows.count {
      // Remove the app bundle id from the window
      if windows[i].appBundleId == "NULL-APP-BUNDLE-ID" {
        windows[i].appBundleId = "com.neovide.neovide"
      }
    }

    var spaces = Dictionary(grouping: windows, by: { $0.workspace })
      .map {
        spaceIdentifier, windows in
        Space(
          name: spaceIdentifier,
          windows: windows,
          isFocused: false
        )
      }
      .sorted(using: KeyPathComparator(\.name))

    if let focusedWindow = self.focusedWindow(),
      let focusedSpaceIndex = spaces.firstIndex(where: { $0.name == focusedWindow.workspace }),
      let focusedWindowIndex = spaces[focusedSpaceIndex].windows.firstIndex(where: {
        $0.windowId == focusedWindow.windowId
      })
    {
      spaces[focusedSpaceIndex].isFocused = true
      spaces[focusedSpaceIndex].windows[focusedWindowIndex].isFocused = true
    } else {
      for i in 0..<spaces.count {
        spaces[i].isFocused = false
        for j in 0..<spaces[i].windows.count {
          spaces[i].windows[j].isFocused = false
        }
      }
    }

    self.spaces = spaces
  }

  func focusedWindow() -> Window? {
    guard
      let result = CommandRunner.runAeroSpaceCommand(withArguments: [
        "list-windows",
        "--focused",
        "--json",
        "--format",
        "%{window-id} %{app-bundle-id} %{workspace}",
      ])
    else {
      return nil
    }

    guard let windows = try? JSONDecoder().decode([Window].self, from: result) else {
      return nil
    }

    return windows.first
  }
}

extension SpaceStation: EventMonitorDelegate {
  func didObserveEvent() {
    self.updateSpaces()
  }
}
