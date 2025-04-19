import AXSwift
import PromiseKit
import SwiftUI

@MainActor
@main
struct SpaceStationApp: App {
  @State var spaceStation = SpaceStation()

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
      Button("One") {
        print("Button one pressed")
      }
    } label: {
      Text("\(self.spaceStation.spaces.first ?? -1)")
    }
  }
}
