import AXSwift
import PromiseKit
import SwiftUI

@MainActor
@main
struct SpaceStationApp: App {
  @StateObject var spaceStation = SpaceStation()
  private let windowController = FloatingWindowController()

  @MainActor
  init() {
    print("Launching SpaceStation")

    guard AXSwift.checkIsProcessTrusted(prompt: true) else {
      print("Not trusted as an AX process; please authorize and re-launch")
      NSApp.terminate(self)
      return
    }

    print("Trusted!")
  }

  @MainActor
  var body: some Scene {
    menuBar()
      .onChange(of: spaceStation.shouldDisplay) { _, shouldDisplay in
        if shouldDisplay {
          windowController.showWindow(with: SpaceStationView(), spaceStation: spaceStation)
        } else {
          windowController.hideWindow()
        }
      }
  }

  func menuBar() -> some Scene {
    MenuBarExtra {
      ForEach(spaceStation.spaces, id: \.name) { space in
        Button {
          _ = CommandRunner.runAeroSpaceCommand(
            withArguments: ["workspace", space.name]
          )
          self.spaceStation.updateSpaces()
        } label: {
          SpaceStationMenuBarView(space: space)
        }
      }

      Divider()

      Button {
        NSApp.terminate(self)
      } label: {
        Text("Quit")
      }
    } label: {
      if let space = spaceStation.spaces.first(where: { $0.isFocused }) {
        SpaceStationMenuBarView(space: space)
      } else {
        Text("SpaceStation")
      }
    }
  }
}
