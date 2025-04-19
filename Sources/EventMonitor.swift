import AppKit
import Foundation
import Swindler

protocol EventMonitorDelegate: AnyObject {
  func didObserveEvent()
}

class EventMonitor {
  var delgate: EventMonitorDelegate?

  private var timer: Timer?

  private var optionDown: Bool = false {
    didSet {
      guard self.optionDown != oldValue else {
        return
      }

      self.delgate?.didObserveEvent()
      self.optionDown ? startRecurringTimer() : stopRecurringTimer()
    }
  }

  private var swindler: Swindler.State!

  init() {
    self.setupModifierEventMonitor()
    self.setupWindowEventMonitor()
  }

  func setupModifierEventMonitor() {
    NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) {
      [weak self] (event) in
      self?.optionDown = NSEvent.modifierFlags.contains(.option)
    }
  }

  func setupWindowEventMonitor() {
    Swindler.initialize().done { state in
      self.swindler = state

      self.swindler.on { (event: FrontmostApplicationChangedEvent) in
        self.delgate?.didObserveEvent()
      }

      self.swindler.on { (event: ApplicationFocusedWindowChangedEvent) in
        self.delgate?.didObserveEvent()
      }

    }.catch { error in
      print(
        "Fatal error: failed to initialize Swindler: \(String(describing: error))")
      NSApp.terminate(self)
    }
  }

  private func startRecurringTimer() {
    stopRecurringTimer()

    timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
      self?.handleTimerFired()
    }
  }

  private func stopRecurringTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func handleTimerFired() {
    self.delgate?.didObserveEvent()
  }
}
