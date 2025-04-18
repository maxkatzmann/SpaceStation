import AXSwift
import PromiseKit
import SwiftUI

@MainActor
@main
struct SpaceStation: App {
  @State var currentNumber: String = "1"

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
    MenuBarExtra(currentNumber, systemImage: "\(currentNumber).circle") {
      // 3
      Button("One") {
        currentNumber = "1"
      }
      Button("Two") {
        currentNumber = "2"
      }
      Button("Three") {
        currentNumber = "3"
      }
    }
  }
}
