import AppKit
import Foundation
import Swindler

protocol EventMonitorDelegate: AnyObject {
  func didObserveEvent()

  // Called when the option key is held uninterrupted for a specific time.
  func isHolding()
  // Called when the option key is released.
  func didRelease()
  // Called when a specific key is pressed for which we listened.
  func didObserveKey(event: NSEvent)
}

class EventMonitor {
  var delegate: EventMonitorDelegate?

  private var recurringTimer: Timer?
  private var uninterruptedOptionDownTimer: Timer?

  private var optionDown: Bool = false {
    didSet {
      guard self.optionDown != oldValue else {
        return
      }

      self.sendEvent()
      self.optionDown ? startRecurringTimer() : stopRecurringTimer()
      self.optionDown ? startUninterruptedOptionDownTimer() : stopUninterruptedOptionDownTimer()

      if !self.optionDown {
        self.delegate?.didRelease()
      }
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
    // We want to be able to cancel the timer that is
    // used to determine when the option key is held,
    // e.g., pressing opt+backspace is definitely not
    // meant to trigger the holding.
    self.setupKeyPressMonitor()
  }

  func setupModifierEventMonitor() {
    NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) {
      [weak self] (event) in
      self?.optionDown = NSEvent.modifierFlags.contains(.option)
    }
  }

  func setupKeyPressMonitor() {
    NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
      if self?.uninterruptedOptionDownTimer != nil {
        self?.stopUninterruptedOptionDownTimer()
      }

      self?.delegate?.didObserveKey(event: event)
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
      // We stop the timer if we received an event. If the window is not shown,
      // by now but the user is already manipulating the spaces, then we assume that
      // they do no need the window.
      self.stopUninterruptedOptionDownTimer()
    }
  }

  private func startRecurringTimer() {
    stopRecurringTimer()

    recurringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
      self?.sendEvent()
    }
  }

  private func stopRecurringTimer() {
    recurringTimer?.invalidate()
    recurringTimer = nil
  }

  private func startUninterruptedOptionDownTimer() {
    stopUninterruptedOptionDownTimer()
    uninterruptedOptionDownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) {
      [weak self] _ in
      self?.delegate?.isHolding()
    }
  }

  private func stopUninterruptedOptionDownTimer() {
    uninterruptedOptionDownTimer?.invalidate()
    uninterruptedOptionDownTimer = nil
  }

  private func sendEvent(withDelay: Bool = false) {
    if withDelay {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.delegate?.didObserveEvent()
      }
    } else {
      self.delegate?.didObserveEvent()
    }
  }
}
