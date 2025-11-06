import Foundation
import os.log

class CommandRunner {
  private static let logger = Logger(subsystem: "com.spacestation.app", category: "CommandRunner")
  
  static func runAeroSpaceCommand(withArguments arguments: [String]) -> Data? {
    logger.info("Running command with arguments: \(arguments, privacy: .public)")
    let process = Process()
    process.executableURL = URL(
      fileURLWithPath:
        "/Users/mkatzmann/Local/AeroSpace/.release/aerospace"
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
      logger.error("Error running command: \(error, privacy: .public)")
      return nil
    }
  }
}
