import SwiftUI

struct VisualEffectView: NSViewRepresentable {
  var material: NSVisualEffectView.Material
  var blendingMode: NSVisualEffectView.BlendingMode

  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = material
    view.blendingMode = blendingMode
    view.state = .active
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    nsView.material = material
    nsView.blendingMode = blendingMode
  }
}

struct WindowView: View {
  let window: Window
  let spaceStation: SpaceStation
  @State private var isHovering = false

  // Since clicks can turn into a drag easily, we additionally
  // enable selection upon drag end.
  var drag: some Gesture {
    DragGesture()
      .onEnded { _ in
        didClick()
      }
  }

  var body: some View {
    if window.isBlank {
      Color.clear
    } else {
      Button(action: {
        didClick()
      }) {
        if let app = NSWorkspace.shared.runningApplications.first(where: {
          $0.bundleIdentifier == window.appBundleId
        }),
          let icon = app.icon
        {
          Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .brightness(isHovering ? 0.2 : 0)
        } else {
          Image(systemName: window.appBundleId)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 30.0, height: 30.0, alignment: .center)
            .padding(50)
            .background(Color.black.opacity(isHovering ? 0.3 : 0.2))
            .frame(width: 80.0, height: 80.0, alignment: .center)
            .cornerRadius(15)
        }
      }
      .buttonStyle(PlainButtonStyle())
      .onHover { hovering in
        isHovering = hovering
      }
      .gesture(drag)
    }
  }

  func didClick() {
    spaceStation.focus(window: window)
    spaceStation.didRelease()
  }
}

struct SpaceView: View {
  @ObservedObject var space: Space
  @Binding var scrollOffset: CGPoint
  let spaceStation: SpaceStation
  let scrollFactor: CGFloat = 50.0

  var body: some View {
    HStack(spacing: 0) {
      let groups = groupContinuousWindows(space.windows)

      ForEach(Array(groups.enumerated()), id: \.offset) { index, windowGroup in
        HStack(spacing: 0) {
          ForEach(windowGroup, id: \.self) { window in
            WindowView(window: window, spaceStation: spaceStation)
              .frame(width: 100.0, height: 100.0, alignment: .center)
          }
        }
        .padding(5)
        .background {
          if !(windowGroup.first?.isBlank ?? true) {
            RoundedRectangle(cornerRadius: 15)
              .fill(Color.gray.opacity(0.2))
          }
        }
        .overlay {
          if !(windowGroup.first?.isBlank ?? true) && space.focusedIndex == nil {
            VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
              .opacity(0.9)
              .cornerRadius(15)
          }
        }
        .offset(x: space.isFocused ? scrollOffset.x * scrollFactor : 0)
      }
    }
  }

  private func groupContinuousWindows(_ windows: [Window]) -> [[Window]] {
    let firstNonBlankIndex = windows.firstIndex(where: { !$0.isBlank })
    let lastNonBlankIndex = windows.lastIndex(where: { !$0.isBlank })

    var groups: [[Window]] = []

    if let firstNonBlankIndex, let lastNonBlankIndex {
      if firstNonBlankIndex > 0 {
        groups.append(Array(windows[0..<firstNonBlankIndex]))
      } else {
        groups.append([])
      }

      groups.append(Array(windows[firstNonBlankIndex...lastNonBlankIndex]))

      if lastNonBlankIndex < windows.count - 1 {
        groups.append(Array(windows[(lastNonBlankIndex + 1)...]))
      } else {
        groups.append([])
      }

      return groups
    }

    return [] + [windows] + []
  }
}

struct SpaceStationView: View {
  @EnvironmentObject var spaceStation: SpaceStation
  let scrollFactor: CGFloat = 75.0

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        VStack {
          Spacer()
          HStack {
            Spacer()
            Color.black.opacity(0.75)
              .frame(width: 100.0, height: 100.0, alignment: .center)
              .cornerRadius(8)
            Spacer()
          }
          Spacer()
        }

        VStack(spacing: 10) {
          ForEach(spaceStation.spacesRepresentation, id: \.self) { space in
            SpaceView(
              space: space, scrollOffset: $spaceStation.scrollOffset, spaceStation: spaceStation)
          }
        }
        .offset(y: -spaceStation.scrollOffset.y * scrollFactor)
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        .clipped()  // This ensures content outside the frame is not visible
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(20)
      .background {
        VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
          .cornerRadius(10)
      }
    }
  }
}
