import Foundation
import SwiftUI

struct Space {
  let name: String
  let windows: [Window]
  let isFocused: Bool
}

// Define a struct to represent window information
struct Window: Codable, Hashable {
  let windowId: Int
  let appBundleId: String
  let workspace: String
  let workspaceIsFocused: Bool

  enum CodingKeys: String, CodingKey {
    case windowId = "window-id"
    case appBundleId = "app-bundle-id"
    case workspace
    case workspaceIsFocused = "workspace-is-focused"
  }
}

// @Observable
class SpaceStation: ObservableObject {
  private let eventMonitor = EventMonitor()

  @Published var spaces: [Space] = []

  init() {
    self.eventMonitor.delgate = self
  }

  func updateWindowState() {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(
      fileURLWithPath:
        "/Users/mkatzmann/Documents/Development/util/AeroSpace/.build/arm64-apple-macosx/debug/aerospace"
    )
    process.arguments = [
      "list-windows",
      "--all",
      "--json",
      "--format",
      "%{window-id} %{app-bundle-id} %{workspace} %{workspace-is-focused}",
    ]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      if let output = String(data: data, encoding: .utf8) {
        if let jsonData = output.data(using: .utf8) {
          let decoder = JSONDecoder()
          do {
            let windows = try decoder.decode([Window].self, from: jsonData)
            self.spaces = Dictionary(grouping: windows, by: { $0.workspace })
              .map {
                spaceIdentifier, windows in
                Space(
                  name: spaceIdentifier,
                  windows: windows,
                  isFocused: windows.contains { $0.workspaceIsFocused }
                )
              }
              .sorted(using: KeyPathComparator(\.name))
          } catch {
            print("Error decoding JSON: \(error)")
          }
        }
      }
      process.waitUntilExit()
    } catch {
      print("Error running command: \(error)")
    }
  }
}

extension SpaceStation: EventMonitorDelegate {
  func didObserveEvent() {
    self.updateWindowState()
  }
}
