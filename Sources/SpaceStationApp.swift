import AXSwift
import PromiseKit
import SwiftUI

@MainActor
@main
struct SpaceStationApp: App {
  @StateObject var spaceStation = SpaceStation()

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
  }

  func menuBar() -> some Scene {
    MenuBarExtra {
      ForEach(spaceStation.spaces, id: \.name) { space in
        Button {
          CommandRunner.runAeroSpaceCommand(
            withArguments: ["workspace", space.name]
          )
          self.spaceStation.updateSpaces()
        } label: {
          SpaceStationView(space: space)
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
        SpaceStationView(space: space)
      } else {
        Text("SpaceStation")
      }
    }
  }
}
