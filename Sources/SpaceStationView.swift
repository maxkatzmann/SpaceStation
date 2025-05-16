import SwiftUI

// TODO: We should blur / make transparent, the spaces for which we do not know the last selected index.
// TODO: We should show the window when the alt-key is pressed long enough
// TODO: We should handle better that we always consider the next empty space as well, and we can scroll to that one but it's only half the height.

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

  var body: some View {
    if window.isBlank {
      Color.clear
    } else {
      if let app = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == window.appBundleId
      }),
        let icon = app.icon
      {
        Image(nsImage: icon)
          .resizable()
          .aspectRatio(contentMode: .fit)
      } else {
        Text(window.appBundleId)
          .frame(width: 80.0, height: 80.0, alignment: .center)
          .background(Color.blue)
          .cornerRadius(15)
      }
    }
  }
}

struct SpaceView: View {
  @ObservedObject var space: Space
  @Binding var scrollOffset: CGPoint
  let scrollFactor: CGFloat = 50.0

  var body: some View {
    HStack(spacing: 0) {
      let groups = groupContinuousWindows(space.windows)

      ForEach(Array(groups.enumerated()), id: \.offset) { index, windowGroup in
        HStack(spacing: 0) {
          ForEach(windowGroup, id: \.self) { window in
            WindowView(window: window)
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
    ZStack {
      VStack {
        Spacer()
        HStack {
          Spacer()
          Color.black.opacity(0.33)
            .frame(width: 100.0, height: 100.0, alignment: .center)
            .cornerRadius(8)
          Spacer()
        }
        Spacer()
      }
      VStack(spacing: 10) {
        ForEach(spaceStation.spacesRepresentation, id: \.self) { space in
          SpaceView(space: space, scrollOffset: $spaceStation.scrollOffset)
        }
      }.offset(y: -spaceStation.scrollOffset.y * scrollFactor)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
    .background {
      VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
        .cornerRadius(10)
    }
  }
}
