import SwiftUI

struct SpaceStationView: View {
  @Environment(\.colorScheme) var colorScheme: ColorScheme
  var space: Space

  var name: String { space.name }
  var bundleIdentifiers: [String] { space.windows.map { $0.appBundleId } }
  // var focussedIndex: Int? { workspaceDisplayInfo.indexOfFocussed }

  var body: some View {
    let renderer = ImageRenderer(
      content:
        HStack {
          SpaceIndicator(name: name)
          Spacer(minLength: 20.0)
          ForEach(Array(bundleIdentifiers.enumerated()), id: \.offset) {
            index,
            bundleIdentifier in
            WindowIndicator(
              bundleIdentifier: bundleIdentifier,
              focussed: false  // index == focussedIndex
            )
          }
        }
        .foregroundStyle(colorScheme == .light ? Color.black : Color.white)
    )
    if let cgImage = renderer.cgImage {
      // Using scale: 1 results in a blurry image for unknown reasons
      Image(cgImage, scale: 2, label: Text("?"))
    } else {
      // In case image can't be rendered fallback to plain text
      Text("?")
    }
  }
}

struct SpaceIndicator: View {
  let name: String

  var body: some View {
    switch name {
    case "1":
      Image(systemName: "house")
        .font(.system(.largeTitle))
    case "2":
      Image(systemName: "message")
        .font(.system(.largeTitle))
    case "3":
      Image(systemName: "hammer")
        .font(.system(.largeTitle))
    case "4":
      Image(systemName: "hourglass")
        .font(.system(.largeTitle))
    case _: Text(name).font(.system(.largeTitle))
    }
  }
}

struct WindowIndicator: View {
  @Environment(\.colorScheme) var colorScheme: ColorScheme

  let bundleIdentifier: String
  let focussed: Bool

  var body: some View {
    VStack(spacing: 2.5) {
      if let app = NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == bundleIdentifier
      }),
        let icon = app.icon
      {
        Image(nsImage: icon)
          .resizable()
          .aspectRatio(contentMode: .fit)
      }
      Rectangle()
        .fill(focussed ? Color.white : Color.white.opacity(0.25))
        .frame(height: 5)
        .cornerRadius(2)
    }
  }
}
