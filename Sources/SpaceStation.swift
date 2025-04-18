import AXSwift
import PromiseKit
import SwiftUI

@MainActor
@main
struct SpaceStation: App {
  @State var eventMonitor = EventMonitor()

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
      Text(self.eventMonitor.code + " " + (self.eventMonitor.optionDown ? "option" : ""))
    }
  }
}
