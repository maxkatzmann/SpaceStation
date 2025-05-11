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
      (1 << CGEventType.scrollWheel.rawValue) | (1 << CGEventType.tapDisabledByTimeout.rawValue)
      | (1 << CGEventType.tapDisabledByUserInput.rawValue)

    // Create the event tap.
    // .cghidEventTap taps events at a low level, before they are posted to applications.
    guard
      let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,  // Tap location
        place: .headInsertEventTap,  // Insert at the head of the event stream
        options: .defaultTap,  // Default behavior (can modify events)
        eventsOfInterest: eventsToTap,  // Mask for the events we want
        callback: eventTapCallback,  // Our C callback function
        userInfo: selfPtr  // Pointer to self (EventTapManager instance)
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
