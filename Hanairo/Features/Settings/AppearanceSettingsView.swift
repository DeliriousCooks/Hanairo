import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Display") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
            }

            Section {
                LabeledContent("Fade Position") {
                    Text(
                        settings.profileBackgroundScreenRatio,
                        format: .percent.precision(.fractionLength(0))
                    )
                    .foregroundStyle(.secondary)
                }

                Slider(
                    value: $settings.profileBackgroundScreenRatio,
                    in: AppSettings.profileBackgroundScreenRatioRange,
                    step: 0.05
                ) {
                    Text("Background Area")
                } minimumValueLabel: {
                    Text("Short")
                } maximumValueLabel: {
                    Text("Long")
                }
            } header: {
                Text("Artist Profile Background")
            } footer: {
                Text("Sets where the background image fully fades out relative to screen height.")
            }

            Section {
                Picker("Detail Quality", selection: $settings.imageQuality) {
                    ForEach(ArtworkImageQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            } header: {
                Text("Images")
            } footer: {
                Text("Quality settings apply to artwork images loaded from now on. Cached content won't be downloaded again.")
            }

            Section {
                Toggle("Parallax Scrolling", isOn: $settings.artworkParallaxEnabled)
            } header: {
                Text("Artwork Details")
            } footer: {
                Text("When on, images shift with a parallax effect and fade into the page background as the info card appears. When off, images are laid out normally.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance & Images")
    }
}

#Preview("Appearance & Images") {
    NavigationStack {
        AppearanceSettingsView()
    }
    .withPreviewDependencies()
}
