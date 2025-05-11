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

  var body: some View {
    HStack(spacing: 0) {
      ForEach(space.windows, id: \.self) { window in
        WindowView(window: window)
          .frame(width: 100.0, height: 100.0, alignment: .center)
      }
    }
  }
}

struct SpaceStationView: View {
  @EnvironmentObject var spaceStation: SpaceStation

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
      VStack(spacing: 0) {
        ForEach(spaceStation.spacesRepresentation, id: \.self) { space in
          SpaceView(space: space)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(20)
    .background {
      VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
        .cornerRadius(25)
    }
  }
}
