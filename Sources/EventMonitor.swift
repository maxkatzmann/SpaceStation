import AppKit
import Foundation
import Swindler

protocol EventMonitorDelegate: AnyObject {
  func didObserveEvent()
}

class EventMonitor {
  var delegate: EventMonitorDelegate?

  private var timer: Timer?

  private var optionDown: Bool = false {
    didSet {
      guard self.optionDown != oldValue else {
        return
      }

      self.sendEvent()
      self.optionDown ? startRecurringTimer() : stopRecurringTimer()
    }
  }

  private var swindler: Swindler.State!

  init() {
    // Events related to using the option modifier
    self.setupModifierEventMonitor()
    // Events related creation / destruction of windows
    self.setupWindowEventMonitor()
    // Events triggered by AeroSpace
    self.setupDistributedNotificationObserver()
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

      // We send these events with a delay to avoid crashes in AeroSpace,
      // which probably occur since AeroSpace has some internal cleanup to
      // do, before the state is ready to be queried again.
      self.swindler.on { (event: WindowCreatedEvent) in
        self.sendEvent(withDelay: true)
      }

      self.swindler.on { (event: WindowDestroyedEvent) in
        self.sendEvent(withDelay: true)
      }
    }.catch { error in
      print(
        "Fatal error: failed to initialize Swindler: \(String(describing: error))")
      NSApp.terminate(self)
    }
  }

  private func setupDistributedNotificationObserver() {
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(externalEventReceived(_:)),
      name: NSNotification.Name("com.nsintegermax.spacestation.event"),
      object: nil
    )
  }

  @objc private func externalEventReceived(_ notification: Notification) {
    DispatchQueue.main.async {
      self.sendEvent()
    }
  }

  private func startRecurringTimer() {
    stopRecurringTimer()

    timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.sendEvent()
    }
  }

  private func stopRecurringTimer() {
    timer?.invalidate()
    timer = nil
  }

  private func sendEvent(withDelay: Bool = false) {
    if withDelay {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        self.delegate?.didObserveEvent()
      }
    } else {
      self.delegate?.didObserveEvent()
    }
  }
}
