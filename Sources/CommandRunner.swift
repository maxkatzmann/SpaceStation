import Foundation

class CommandRunner {
  static func runAeroSpaceCommand(withArguments arguments: [String]) -> Data? {
    let process = Process()
    process.executableURL = URL(
      fileURLWithPath:
        "/Users/mkatzmann/Local/AeroSpace/.debug/aerospace"
    )
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    do {
      try process.run()
      process.waitUntilExit()
      return pipe.fileHandleForReading.readDataToEndOfFile()
    } catch {
      print("Error running command: \(error)")
      return nil
    }
  }
}
