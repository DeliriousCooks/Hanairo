import Foundation
import SwiftUI

struct CacheSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ImageRepository.self) private var imageRepository
    @Environment(PixivRepository.self) private var repository
    @Environment(UgoiraRepository.self) private var ugoiraRepository

    @State private var imageUsage: CacheUsage?
    @State private var detailUsage: CacheUsage?
    @State private var ugoiraUsage: CacheUsage?
    @State private var pendingClear: CacheClearTarget?
    @State private var activeClear: CacheClearTarget?

    private var totalUsageText: String {
        guard let imageUsage, let detailUsage, let ugoiraUsage else { return "Calculating…" }
        return CacheByteCountFormatter.string(
            imageUsage.byteCount + detailUsage.byteCount + ugoiraUsage.byteCount
        )
    }

    private var showsClearConfirmation: Binding<Bool> {
        Binding {
            pendingClear != nil
        } set: { isPresented in
            if !isPresented {
                pendingClear = nil
            }
        }
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Overview") {
                LabeledContent("Total Cache Usage", value: totalUsageText)
            }

            Section {
                CacheUsageRows(usage: imageUsage)

                Stepper(
                    "Max size: \(settings.imageCacheLimitMB) MB",
                    value: $settings.imageCacheLimitMB,
                    in: AppSettings.imageCacheLimitRange,
                    step: 50
                )

                CacheClearButton(
                    title: "Clear Image Cache",
                    isWorking: isClearing(.images),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.images)
                }
            } header: {
                Text("Image Cache")
            } footer: {
                Text("Thumbnails and artwork images use the disk cache first. When the size limit is exceeded, the least recently used files are deleted automatically. Clearing also frees images held in memory.")
            }

            Section {
                Toggle("Enable Artwork Details Cache", isOn: $settings.detailCacheEnabled)

                CacheUsageRows(usage: detailUsage)

                Stepper(
                    "Max size: \(settings.detailCacheLimitMB) MB",
                    value: $settings.detailCacheLimitMB,
                    in: AppSettings.detailCacheLimitRange,
                    step: 5
                )
                .disabled(!settings.detailCacheEnabled)

                CacheClearButton(
                    title: "Clear Artwork Details Cache",
                    isWorking: isClearing(.details),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.details)
                }
            } header: {
                Text("Artwork Details Cache")
            } footer: {
                Text("When on, reopening an artwork shows local details first, then updates from Pixiv. Turning this off doesn't delete the existing cache.")
            }

            Section {
                CacheUsageRows(usage: ugoiraUsage)

                Stepper(
                    "Max size: \(settings.ugoiraCacheLimitMB) MB",
                    value: $settings.ugoiraCacheLimitMB,
                    in: AppSettings.ugoiraCacheLimitRange,
                    step: 50
                )

                CacheClearButton(
                    title: "Clear Ugoira Cache",
                    isWorking: isClearing(.ugoira),
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.ugoira)
                }
            } header: {
                Text("Ugoira Cache")
            } footer: {
                Text("Original ugoira archives are stored locally so they don't need to be downloaded again. When the size limit is exceeded, the least recently used files are cleaned up automatically.")
            }

            Section("Clean Up") {
                CacheClearButton(
                    title: "Clear All Caches",
                    isWorking: activeClear == .all,
                    isDisabled: activeClear != nil
                ) {
                    requestClear(.all)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Cache")
        .task {
            await prepareAndRefreshUsage()
        }
        .refreshable {
            await refreshUsage()
        }
        .onChange(of: settings.imageCacheLimitMB) { _, _ in
            applyImageCacheCapacity()
        }
        .onChange(of: settings.detailCacheLimitMB) { _, _ in
            applyDetailCacheCapacity()
        }
        .onChange(of: settings.ugoiraCacheLimitMB) { _, _ in
            applyUgoiraCacheCapacity()
        }
        .confirmationDialog(
            pendingClear?.confirmationTitle ?? "Clear cache?",
            isPresented: showsClearConfirmation,
            titleVisibility: .visible,
            presenting: pendingClear
        ) { target in
            Button(target.actionTitle, role: .destructive) {
                performClear(target)
            }
            Button("Cancel", role: .cancel) {}
        } message: { target in
            Text(target.message)
        }
    }

    private func isClearing(_ target: CacheClearTarget) -> Bool {
        activeClear == target || activeClear == .all
    }

    private func requestClear(_ target: CacheClearTarget) {
        pendingClear = target
    }

    private func performClear(_ target: CacheClearTarget) {
        pendingClear = nil
        Task {
            await clear(target)
        }
    }

    private func applyImageCacheCapacity() {
        Task {
            await imageRepository.updateCacheCapacity()
            await refreshUsage()
        }
    }

    private func applyDetailCacheCapacity() {
        Task {
            await repository.updateDetailCacheCapacity()
            await refreshUsage()
        }
    }

    private func applyUgoiraCacheCapacity() {
        Task {
            await ugoiraRepository.updateCacheCapacity()
            await refreshUsage()
        }
    }

    private func prepareAndRefreshUsage() async {
        await imageRepository.updateCacheCapacity()
        await repository.updateDetailCacheCapacity()
        await ugoiraRepository.updateCacheCapacity()
        await refreshUsage()
    }

    private func refreshUsage() async {
        async let nextImageUsage = imageRepository.cacheUsage()
        async let nextDetailUsage = repository.detailCacheUsage()
        async let nextUgoiraUsage = ugoiraRepository.cacheUsage()
        let usages = await (nextImageUsage, nextDetailUsage, nextUgoiraUsage)
        guard !Task.isCancelled else { return }
        imageUsage = usages.0
        detailUsage = usages.1
        ugoiraUsage = usages.2
    }

    private func clear(_ target: CacheClearTarget) async {
        guard activeClear == nil else { return }
        activeClear = target
        defer { activeClear = nil }

        switch target {
        case .images:
            await imageRepository.clear()
        case .details:
            await repository.clearDetailCache()
        case .ugoira:
            await ugoiraRepository.clear()
        case .all:
            await imageRepository.clear()
            await repository.clearDetailCache()
            await ugoiraRepository.clear()
        }
        await refreshUsage()
    }
}

private struct CacheUsageRows: View {
    let usage: CacheUsage?

    var body: some View {
        if let usage {
            LabeledContent(
                "Current Usage",
                value: CacheByteCountFormatter.string(usage.byteCount)
            )
            LabeledContent("Cached Items", value: "\(usage.itemCount) items")
            ProgressView(value: usage.fraction) {
                Text("Capacity Used")
            } currentValueLabel: {
                Text(
                    "\(CacheByteCountFormatter.string(usage.byteCount)) / "
                        + CacheByteCountFormatter.string(usage.capacityBytes)
                )
                .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 10) {
                ProgressView()
                Text("Calculating usage…")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CacheClearButton: View {
    let title: String
    let isWorking: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            if isWorking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Clearing…")
                }
            } else {
                Label(title, systemImage: "trash")
            }
        }
        .disabled(isDisabled)
    }
}

private enum CacheClearTarget: Equatable {
    case images
    case details
    case ugoira
    case all

    var confirmationTitle: String {
        switch self {
        case .images: "Clear image cache?"
        case .details: "Clear artwork details cache?"
        case .ugoira: "Clear ugoira cache?"
        case .all: "Clear all caches?"
        }
    }

    var actionTitle: String {
        switch self {
        case .images: "Clear Image Cache"
        case .details: "Clear Details Cache"
        case .ugoira: "Clear Ugoira Cache"
        case .all: "Clear All"
        }
    }

    var message: String {
        switch self {
        case .images:
            "This deletes cached thumbnails and artwork images. Images already saved to the photo library or Files aren't affected."
        case .details:
            "This deletes locally stored artwork details. They'll be fetched from Pixiv again the next time you open them."
        case .ugoira:
            "This deletes locally stored ugoira archives. They'll be downloaded again the next time you play them."
        case .all:
            "This deletes the image, ugoira, and artwork details caches. Your sign-in status, bookmarks, and downloaded files aren't affected."
        }
    }
}

private nonisolated enum CacheByteCountFormatter {
    static func string(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }
}

#Preview("Cache") {
    NavigationStack {
        CacheSettingsView()
    }
    .withPreviewDependencies()
}
