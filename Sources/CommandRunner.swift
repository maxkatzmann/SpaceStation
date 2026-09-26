import Foundation
import os.log

enum CommandRunner {
  fileprivate static let logger = Logger(subsystem: "com.spacestation.app", category: "CommandRunner")

  static func runAeroSpaceCommand(withArguments arguments: [String]) async -> Data? {
    logger.info("Running command with arguments: \(arguments, privacy: .public)")
    let command = RunningCommand()
    return await withTaskCancellationHandler {
      await command.run(arguments: arguments)
    } onCancel: {
      command.cancel()
    }
  }
}

private final class RunningCommand: @unchecked Sendable {
  private let lock = NSLock()
  private var continuation: CheckedContinuation<Data?, Never>?
  private var process: Process?
  private var timeoutTimer: DispatchSourceTimer?
  private var isCancelled = false

  func run(arguments: [String]) async -> Data? {
    await withCheckedContinuation { continuation in
      let process = Process()
      let pipe = Pipe()
      process.executableURL = URL(fileURLWithPath: "/Users/mkatzmann/Local/AeroSpace/.release/aerospace")
      process.arguments = arguments
      process.standardOutput = pipe
      process.standardError = pipe
      process.terminationHandler = { [weak self] _ in
        self?.finish(with: pipe.fileHandleForReading.readDataToEndOfFile())
      }

      lock.lock()
      guard !isCancelled else {
        lock.unlock()
        continuation.resume(returning: nil)
        return
      }
      self.continuation = continuation
      self.process = process
      lock.unlock()

      do {
        try process.run()
        startTimeout()
      } catch {
        CommandRunner.logger.error("Error running AeroSpace command: \(error, privacy: .public)")
        finish(with: nil)
      }
    }
  }

  func cancel() {
    lock.lock()
    isCancelled = true
    lock.unlock()
    finish(with: nil, terminateProcess: true)
  }

  private func startTimeout() {
    let timer = DispatchSource.makeTimerSource(queue: .global())
    timer.schedule(deadline: .now() + .seconds(2))
    timer.setEventHandler { [weak self] in
      CommandRunner.logger.error("AeroSpace command timed out")
      self?.finish(with: nil, terminateProcess: true)
    }

    lock.lock()
    guard continuation != nil else {
      lock.unlock()
      timer.cancel()
      return
    }
    timeoutTimer = timer
    lock.unlock()
    timer.resume()
  }

  private func finish(with data: Data?, terminateProcess: Bool = false) {
    lock.lock()
    let continuation = self.continuation
    let process = self.process
    let timer = timeoutTimer
    self.continuation = nil
    self.process = nil
    timeoutTimer = nil
    lock.unlock()

    timer?.cancel()
    if terminateProcess, process?.isRunning == true {
      process?.terminate()
    }
    continuation?.resume(returning: data)
  }
}
