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
    return (0..<count).map { _ in
      Window(windowId: -1, appBundleId: "", workspace: "", isFocused: false, isBlank: true)
    }
  }
}

class SpaceStation: ObservableObject {
  private let eventMonitor = EventMonitor()
  private let touchMonitor = TouchMonitor()
  private var currentUpdateTask: Task<Void, Never>? = nil

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
    guard !spaces.isEmpty, let focusedWorkspace = self.focusedWorkspace() else {
      return nil
    }

    return self.spaces.firstIndex(where: { $0.name == focusedWorkspace })
  }

  init() {
    self.eventMonitor.delegate = self
    self.touchMonitor.delegate = self

    self.updateSpaces()
  }

  func updateSpaces() {
    currentUpdateTask?.cancel()
    currentUpdateTask = Task { [weak self] in
      guard !Task.isCancelled else {
        return
      }

      guard
        let result = CommandRunner.runAeroSpaceCommand(withArguments: [
          "list-windows",
          "--all",
          "--json",
          "--format",
          "%{window-id} %{app-bundle-id} %{workspace}",
        ])
      else {
        return
      }

      guard !Task.isCancelled else {
        return
      }

      guard let windows = try? JSONDecoder().decode([Window].self, from: result) else {
        return
      }

      guard !Task.isCancelled else {
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

      guard !Task.isCancelled else {
        return
      }

      if let focusedWorkspace = self?.focusedWorkspace() {
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
      }

      spaces = spaces.sorted(using: KeyPathComparator(\.name))

      guard !Task.isCancelled else {
        return
      }

      if let focusedWindow = self?.focusedWindow(),
        let focusedSpaceIndex = spaces.firstIndex(where: { $0.isFocused }),
        let focusedWindowIndex = spaces[focusedSpaceIndex].windows.firstIndex(where: {
          $0.windowId == focusedWindow.windowId
        })
      {
        self?.lastFocusedIndexPerSpace[spaces[focusedSpaceIndex].name] = focusedWindowIndex
        spaces[focusedSpaceIndex].windows[focusedWindowIndex].isFocused = true
      } else {
        for i in 0..<spaces.count {
          for j in 0..<spaces[i].windows.count {
            spaces[i].windows[j].isFocused = false
          }
        }
      }

      DispatchQueue.main.async {
        self?.spaces = spaces
        self?.updateSpacesRepresentation()
      }
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

    if let focusedIndex = self.lastFocusedIndexPerSpace[space.name] {
      windows += Window.blanks(count: (windowsPerSpace / 2) - focusedIndex)
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
      focusedIndex: self.lastFocusedIndexPerSpace[space.name])
    return newSpace
  }

  func focusedWorkspace() -> String? {
    guard
      let result = CommandRunner.runAeroSpaceCommand(withArguments: [
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

  func focusedWindow() -> Window? {
    guard
      let result = CommandRunner.runAeroSpaceCommand(withArguments: [
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
    CommandRunner.runAeroSpaceCommand(withArguments: [
      "focus",
      "--window-id",
      "\(window.windowId)",
    ])
  }

  func close(window: Window) {
    CommandRunner.runAeroSpaceCommand(withArguments: [
      "close",
      "--window-id",
      "\(window.windowId)",
    ])
  }
}

extension SpaceStation: EventMonitorDelegate {
  func didObserveEvent() {
    self.updateSpaces()
  }

  func didObserveKey(event: NSEvent) {
    if self.shouldDisplay, event.key == "w", let focusedWindow = self.focusedWindow() {
      self.close(window: focusedWindow)
    }
  }
}

extension SpaceStation: TouchMonitorDelegate {
  func didPan(_ direction: Direction) {
    self.move(in: direction)
  }
  func didSwipe(_ direction: Direction) {
    self.move(in: direction)
  }

  func move(in direction: Direction) {
    switch direction {
    case .left:
      CommandRunner.runAeroSpaceCommand(withArguments: ["focus", "right"])
    case .right:
      CommandRunner.runAeroSpaceCommand(withArguments: ["focus", "left"])
    case .up:
      if let selectedSpace = self.selectedSpace {
        if self.spaces.count > selectedSpace + 1 {
          CommandRunner.runAeroSpaceCommand(withArguments: [
            "workspace", self.spaces[selectedSpace + 1].name,
          ])
        } else {
          CommandRunner.runAeroSpaceCommand(withArguments: [
            "workspace", "\(self.spaces.count + 1)",
          ])
        }
      }
    case .down:
      if let selectedSpace = self.selectedSpace, selectedSpace > 0 {
        CommandRunner.runAeroSpaceCommand(withArguments: [
          "workspace", self.spaces[selectedSpace - 1].name,
        ])
      }
    }

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
