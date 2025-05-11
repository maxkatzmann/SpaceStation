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
