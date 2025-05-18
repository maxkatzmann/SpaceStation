import AppKit
import Foundation

extension NSEvent {
  var key: Character? {
    return self.charactersIgnoringModifiers?.first
  }
}
