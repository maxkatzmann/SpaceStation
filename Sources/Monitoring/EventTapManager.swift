import Cocoa
import CoreGraphics

// The CGEventTap callback function
// This MUST be a C function or a @convention(c) closure.
// It cannot capture Swift class context directly unless passed via the 'refcon' (reference constant).
private func eventTapCallback(
  proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  // Ensure refcon is not nil and correctly cast it to our EventTapManager instance
  guard let managerRef = refcon else {
    // If refcon is nil, pass the event through to avoid unexpected behavior.
    return Unmanaged.passRetained(event)
  }
  let manager = Unmanaged<EventTapManager>.fromOpaque(managerRef).takeUnretainedValue()

  // Check the event type
  switch type {
  case .scrollWheel:
    if manager.isConsumingScrollEvents {
      // If the flag is set, consume the scroll event by returning nil
      return nil
    }
  case .keyDown:
    if manager.isConsumingWKeyPresses {
      // Check if this is a 'w' key press
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
      if keyCode == 13 {  // 13 is the keycode for 'w' on macOS
        // Get the target process ID
        let targetPIDInt64 = event.getIntegerValueField(.eventTargetUnixProcessID)
        guard targetPIDInt64 <= Int64(Int32.max) else {
          return nil  // PID is too large for pid_t
        }
        let targetPID = pid_t(targetPIDInt64)

        // Check if this event is targeted at our application
        if targetPID == manager.ourApplicationPID {
          // Allow the event to go through to our application
          return Unmanaged.passRetained(event)
        } else {
          // Consume the event for other applications
          return nil
        }
      }
    }
  case .tapDisabledByTimeout:
    // The tap has been disabled due to a timeout. Re-enable it.
    if let tap = manager.eventTap {
      CGEvent.tapEnable(tap: tap, enable: true)
    }
    // It's generally safe to pass this event through or consume it.
    // Passing it through is usually fine.
    return Unmanaged.passRetained(event)
  case .tapDisabledByUserInput:
    // This typically means the tap was disabled because the user pressed a key combination
    // (like Command-Option-Escape to open Force Quit). This is unusual for a HID tap.
    // You might want to log this or decide if re-enabling is appropriate.
    // if let tap = manager.eventTap { CGEventTapEnable(tap, true) } // Optional: re-enable
    return Unmanaged.passRetained(event)
  default:
    // For any other event types we might have inadvertently subscribed to,
    // or for events we don't want to consume, pass them through.
    break
  }

  return Unmanaged.passRetained(event)
}

public class EventTapManager {
  public static let shared = EventTapManager()
  fileprivate var eventTap: CFMachPort?
  fileprivate var runLoopSource: CFRunLoopSource?

  // This flag is controlled by our gesture detection logic.
  // When true, the eventTapCallback will consume scroll events.
  public var isConsumingScrollEvents: Bool = false

  // When true, the eventTapCallback will consume 'w' key presses for other apps
  public var isConsumingWKeyPresses: Bool = false

  // Store the PID of our application to allow events through to it
  public var ourApplicationPID: pid_t = ProcessInfo.processInfo.processIdentifier

  public func startTap() {
    // Nothing to do if we are already running.
    guard eventTap == nil else {
      return
    }

    // Pass 'self' as the UnsafeMutableRawPointer to the callback.
    // This allows the C callback to access the Swift class instance.
    let selfPtr = Unmanaged.passUnretained(self).toOpaque()

    // Define the events we are interested in.
    // We need scrollWheel for consumption and tapDisabledByTimeout to keep the tap alive.
    let eventsToTap: CGEventMask =
      (1 << CGEventType.scrollWheel.rawValue) | (1 << CGEventType.keyDown.rawValue)
      | (1 << CGEventType.tapDisabledByTimeout.rawValue)
      | (1 << CGEventType.tapDisabledByUserInput.rawValue)

    // Create the event tap.
    // Using cgAnnotatedSessionEventTap to tap events at session level so we can filter by app
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgAnnotatedSessionEventTap,  // Change to session-level tap
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: eventsToTap,
        callback: eventTapCallback,
        userInfo: selfPtr
      )
    else {
      return
    }
    self.eventTap = tap

    // Create a run loop source for the event tap and add it to the current run loop.
    // This allows the tap to receive events.
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource = runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
    } else {
      self.eventTap = nil  // Clean up if run loop source creation fails
    }
  }

  public func stopTap() {
    guard let tap = eventTap else {
      return
    }

    CGEvent.tapEnable(tap: tap, enable: false)

    if let runLoopSource = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      self.runLoopSource = nil  // Release the source
    }

    // CFMachPortInvalidate(tap) // Call if you are sure you won't use this tap instance again.
    // For a singleton that might be restarted, you might skip invalidation
    // until app termination or full deallocation.
    self.eventTap = nil  // Release the tap port
  }

  deinit {
    // Ensure the tap is stopped when the manager is deallocated.
    // For a singleton, this typically happens at app termination.
    stopTap()
  }
}
