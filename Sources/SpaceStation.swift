import Foundation
import SwiftUI

class Space: Identifiable, Hashable, ObservableObject {
  let name: String
  var windows: [Window]
  var isFocused: Bool = false
  var focusedIndex: Int? = nil

  init(name: String, windows: [Window], isFocused: Bool = false, focusedIndex: Int? = nil) {
    self.name = name
    self.windows = windows
    self.isFocused = isFocused
    self.focusedIndex = focusedIndex
  }

  static func == (lhs: Space, rhs: Space) -> Bool {
    return lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func blanks(count: Int, windowCount: Int) -> [Space] {
    guard count > 0 else {
      return []
    }
    return (0..<count).map { _ in Space(name: "blank", windows: Window.blanks(count: windowCount)) }
  }
}

struct SpaceSelection: Codable {
  let workspace: String
}

// Define a struct to represent window information
class Window: Codable, Identifiable, Hashable {
  let windowId: Int
  var appBundleId: String
  let workspace: String
  var isFocused: Bool = false
  var isBlank: Bool = false
  var isAddButton: Bool = false

  enum CodingKeys: String, CodingKey {
    case windowId = "window-id"
    case appBundleId = "app-bundle-id"
    case workspace
  }

  init(
    windowId: Int,
    appBundleId: String,
    workspace: String,
    isFocused: Bool = false,
    isBlank: Bool = false,
    isAddButton: Bool = false
  ) {
    self.windowId = windowId
    self.appBundleId = appBundleId
    self.workspace = workspace
    self.isFocused = isFocused
    self.isBlank = isBlank
    self.isAddButton = isAddButton
  }

  static func == (lhs: Window, rhs: Window) -> Bool {
    return lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func blanks(count: Int) -> [Window] {
    guard count > 0 else {
      return []
    }
    return (0..<count).map { _ in
      Window(windowId: -1, appBundleId: "", workspace: "", isFocused: false, isBlank: true)
    }
  }
}

@MainActor
class SpaceStation: ObservableObject {
  private let eventMonitor = EventMonitor()
  private let touchMonitor = TouchMonitor()
  private var currentUpdateTask: Task<Void, Never>? = nil
  private var updateQueued = false

  @Published var spaces: [Space] = []
  @Published var spacesRepresentation: [Space] = []
  @Published var shouldDisplay = false {
    didSet {
      // Only consume 'w' key presses when the window is shown.
      EventTapManager.shared.isConsumingWKeyPresses = shouldDisplay
    }
  }
  @Published var scrollOffset: CGPoint = .zero

  private var lastFocusedIndexPerSpace: [String: Int] = [:]

  var selectedSpace: Int? {
    spaces.firstIndex(where: \.isFocused)
  }

  init() {
    self.eventMonitor.delegate = self
    self.touchMonitor.delegate = self

    self.updateSpaces()
  }

  func updateSpaces() {
    guard currentUpdateTask == nil else {
      updateQueued = true
      return
    }

    currentUpdateTask = Task { [weak self] in
      guard let self else {
        return
      }

      defer {
        self.currentUpdateTask = nil
        if self.updateQueued {
          self.updateQueued = false
          self.updateSpaces()
        }
      }

      guard
        let result = await CommandRunner.runAeroSpaceCommand(withArguments: [
          "list-windows",
          "--all",
          "--json",
          "--format",
          "%{window-id} %{app-bundle-id} %{workspace}",
        ])
      else {
        return
      }

      guard let windows = try? JSONDecoder().decode([Window].self, from: result) else {
        return
      }

      // Neovide hack. Currently, neovide does not have an appBundleId for any but the very first window.
      for i in 0..<windows.count {
        // Remove the app bundle id from the window
        if windows[i].appBundleId == "NULL-APP-BUNDLE-ID" {
          windows[i].appBundleId = "com.neovide.neovide"
        }
      }

      var spaces = Dictionary(grouping: windows, by: { $0.workspace })
        .map {
          spaceIdentifier, windows in
          Space(
            name: spaceIdentifier,
            windows: windows,
            isFocused: false
          )
        }

      guard
        let focusedWorkspace = await self.focusedWorkspace()
      else {
        return
      }
      var spaceFound = false

      for i in 0..<spaces.count {
        if spaces[i].name == focusedWorkspace {
          spaces[i].isFocused = true
          spaceFound = true
        } else {
          spaces[i].isFocused = false
        }
      }

      if !spaceFound {
        spaces.append(
          Space(
            name: focusedWorkspace,
            windows: [],
            isFocused: true
          )
        )
      }

      spaces = spaces.sorted(using: KeyPathComparator(\.name))

      self.pruneFocusedIndices(for: spaces)

      if let focusedWindow = await self.focusedWindow(),
        let focusedSpaceIndex = spaces.firstIndex(where: { $0.isFocused }),
        let focusedWindowIndex = spaces[focusedSpaceIndex].windows.firstIndex(where: {
          $0.windowId == focusedWindow.windowId
        })
      {
        self.lastFocusedIndexPerSpace[spaces[focusedSpaceIndex].name] = focusedWindowIndex
        spaces[focusedSpaceIndex].windows[focusedWindowIndex].isFocused = true
      } else {
        for i in 0..<spaces.count {
          for j in 0..<spaces[i].windows.count {
            spaces[i].windows[j].isFocused = false
          }
        }
      }

      self.spaces = spaces
      self.updateSpacesRepresentation()
    }
  }

  func updateSpacesRepresentation() {
    guard self.spaces.count > 0, let selectedSpace = self.selectedSpace else {
      return
    }

    var spaceCount = self.spaces.count

    // Add an empty space that is supposed to represent adding a new space,
    // but we only do so, if the last space does have some windows, because
    // otherwise that space is already the "new" one.
    let hasAddedSpace: Bool = (self.spaces.last?.windows.count ?? 0) > 0
    if hasAddedSpace {
      spaceCount += 1
    }

    let maxWindowsInSpace = self.spaces.map { $0.windows.count }.max() ?? 1
    let windowsPerSpace = 2 * maxWindowsInSpace - 1
    let totalSpaces = 2 * spaceCount - 1

    var spacesRepresentation = [Space]()

    spacesRepresentation += Space.blanks(
      count: spaceCount - 1 - selectedSpace, windowCount: windowsPerSpace)

    for space in self.spaces {
      spacesRepresentation.append(representation(forSpace: space, windowsPerSpace: windowsPerSpace))
    }

    if hasAddedSpace {
      let lastSpaceNumber = Int(self.spaces.last?.name ?? "0") ?? 0
      spacesRepresentation.append(
        Space(
          name: "\(lastSpaceNumber + 1)",
          windows: [
            Window(
              windowId: -1,
              appBundleId: "plus",
              workspace: "",
              isFocused: false,
              isBlank: false,
              isAddButton: true
            )
          ],
          focusedIndex: 0,
        )
      )
    }

    spacesRepresentation += Space.blanks(
      count: totalSpaces - spacesRepresentation.count, windowCount: windowsPerSpace)

    self.spacesRepresentation = spacesRepresentation
  }

  func representation(forSpace space: Space, windowsPerSpace: Int) -> Space {
    var windows = [Window]()
    let focusedIndex = sanitizedFocusedIndex(for: space)

    if let focusedIndex {
      windows += Window.blanks(count: max(0, (windowsPerSpace / 2) - focusedIndex))
      windows += space.windows
      windows += Window.blanks(count: windowsPerSpace - windows.count)
    } else {
      windows += space.windows
    }

    if space.windows.count == 0 {
      windows += Window.blanks(count: 1)
    }

    let newSpace = Space(
      name: space.name, windows: windows, isFocused: space.isFocused,
      focusedIndex: focusedIndex)
    return newSpace
  }

  func pruneFocusedIndices(for spaces: [Space]) {
    let validSpaceNames = Set(spaces.map(\.name))

    lastFocusedIndexPerSpace = lastFocusedIndexPerSpace.reduce(into: [:]) { result, entry in
      let (spaceName, focusedIndex) = entry

      guard
        validSpaceNames.contains(spaceName),
        let space = spaces.first(where: { $0.name == spaceName }),
        space.windows.indices.contains(focusedIndex)
      else {
        return
      }

      result[spaceName] = focusedIndex
    }
  }

  func sanitizedFocusedIndex(for space: Space) -> Int? {
    guard
      let focusedIndex = self.lastFocusedIndexPerSpace[space.name],
      space.windows.indices.contains(focusedIndex)
    else {
      return nil
    }

    return focusedIndex
  }

  func focusedWorkspace() async -> String? {
    guard
      let result = await CommandRunner.runAeroSpaceCommand(withArguments: [
        "list-workspaces",
        "--focused",
        "--json",
      ])
    else {
      return nil
    }

    guard let selection = try? JSONDecoder().decode([SpaceSelection].self, from: result) else {
      return nil
    }

    return selection.first?.workspace
  }

  func focusedWindow() async -> Window? {
    guard
      let result = await CommandRunner.runAeroSpaceCommand(withArguments: [
        "list-windows",
        "--focused",
        "--json",
        "--format",
        "%{window-id} %{app-bundle-id} %{workspace}",
      ])
    else {
      return nil
    }

    guard let windows = try? JSONDecoder().decode([Window].self, from: result) else {
      return nil
    }

    return windows.first
  }

  func focus(window: Window) {
    Task {
      _ = await CommandRunner.runAeroSpaceCommand(withArguments: [
      "focus",
      "--window-id",
      "\(window.windowId)",
      ])
    }
  }

  func close(window: Window) {
    Task {
      _ = await CommandRunner.runAeroSpaceCommand(withArguments: [
      "close",
      "--window-id",
      "\(window.windowId)",
      ])
    }
  }
}

extension SpaceStation: @preconcurrency EventMonitorDelegate {
  func didObserveEvent() {
    self.updateSpaces()
  }

  func didObserveKey(event: NSEvent) {
    guard self.shouldDisplay, event.key == "w" else {
      return
    }
    Task {
      if let focusedWindow = await self.focusedWindow() {
        self.close(window: focusedWindow)
      }
    }
  }
}

extension SpaceStation: @preconcurrency TouchMonitorDelegate {
  func didPan(_ direction: Direction) {
    self.move(in: direction)
  }
  func didSwipe(_ direction: Direction) {
    self.move(in: direction)
  }

  func move(in direction: Direction) {
    let arguments: [String]?
    switch direction {
    case .left: arguments = ["focus", "right"]
    case .right: arguments = ["focus", "left"]
    case .up:
      guard let selectedSpace else { return }
      arguments = selectedSpace + 1 < spaces.count
        ? ["workspace", spaces[selectedSpace + 1].name]
        : ["workspace", "\(spaces.count + 1)"]
    case .down:
      guard let selectedSpace, selectedSpace > 0 else { return }
      arguments = ["workspace", spaces[selectedSpace - 1].name]
    }

    if let arguments {
      Task {
        _ = await CommandRunner.runAeroSpaceCommand(withArguments: arguments)
        self.updateSpaces()
      }
    }

    // Provide haptic feedback
    let hapticFeedback = NSHapticFeedbackManager.defaultPerformer
    hapticFeedback.perform(.levelChange, performanceTime: .default)

    self.updateSpacesRepresentation()
  }

  func isHolding() {
    self.shouldDisplay = true
  }

  func didRelease() {
    self.shouldDisplay = false
  }

  func didScroll(_ axis: Axis, delta: CGFloat) {
    self.scrollOffset = CGPoint(
      x: axis == .horizontal ? delta : 0,
      y: axis == .vertical ? delta : 0
    )
  }
}
