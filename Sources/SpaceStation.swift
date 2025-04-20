import Foundation
import SwiftUI

struct Space {
  let name: String
  var windows: [Window]
  var isFocused: Bool = false
}

struct SpaceSelection: Codable {
  let workspace: String
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
  private var currentUpdateTask: Task<Void, Never>? = nil

  @Published var spaces: [Space] = []

  init() {
    self.eventMonitor.delegate = self
  }

  func updateSpaces() {
    currentUpdateTask?.cancel()
    currentUpdateTask = Task { [weak self] in
      guard !Task.isCancelled else {
        return
      }

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

      guard !Task.isCancelled else {
        return
      }

      guard var windows = try? JSONDecoder().decode([Window].self, from: result) else {
        return
      }

      guard !Task.isCancelled else {
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

      guard !Task.isCancelled else {
        return
      }

      if let focusedWorkspace = self?.focusedWorkspace() {
        var spaceFound = false

        if focusedWorkspace == "3" {
          print("Here!")
        }

        for i in 0..<spaces.count {
          if spaces[i].name == focusedWorkspace {
            spaces[i].isFocused = true
            spaceFound = true
          } else {
            spaces[i].isFocused = false
          }
        }

        if !spaceFound {
          spaces.append(
            Space(
              name: focusedWorkspace,
              windows: [],
              isFocused: true
            )
          )
        }
      }

      spaces = spaces.sorted(using: KeyPathComparator(\.name))

      guard !Task.isCancelled else {
        return
      }

      if let focusedWindow = self?.focusedWindow(),
        let focusedSpaceIndex = spaces.firstIndex(where: { $0.isFocused }),
        let focusedWindowIndex = spaces[focusedSpaceIndex].windows.firstIndex(where: {
          $0.windowId == focusedWindow.windowId
        })
      {
        spaces[focusedSpaceIndex].windows[focusedWindowIndex].isFocused = true
      } else {
        for i in 0..<spaces.count {
          for j in 0..<spaces[i].windows.count {
            spaces[i].windows[j].isFocused = false
          }
        }
      }

      DispatchQueue.main.async {
        self?.spaces = spaces
      }
    }
  }

  func focusedWorkspace() -> String? {
    guard
      let result = CommandRunner.runAeroSpaceCommand(withArguments: [
        "list-workspaces",
        "--focused",
        "--json",
      ])
    else {
      return nil
    }

    guard let selection = try? JSONDecoder().decode([SpaceSelection].self, from: result) else {
      return nil
    }

    return selection.first?.workspace
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
