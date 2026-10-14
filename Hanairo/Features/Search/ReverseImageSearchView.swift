import ImageIO
import PhotosUI
import SwiftUI

struct ReverseImageSearchView: View {
    @Environment(ReverseImageSearchService.self) private var imageSearch
    @Environment(PixivRepository.self) private var repository

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var state: LoadState<ReverseImageSearchResult> = .idle
    @State private var statusMessage = "Processing image…"
    @State private var activeSearchID: UUID?
    @State private var actionError: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                imageSelectionSection
                resultContent
            }
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle("Reverse Image Search")
        .task(id: selectedItem) {
            guard let selectedItem else { return }
            await search(selectedItem)
        }
        .onDisappear {
            activeSearchID = nil
        }
        .alert("Action Failed", isPresented: actionErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "Unknown error")
        }
    }

    private var imageSelectionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                if let selectedImageData {
                    ReverseImageSearchPreview(data: selectedImageData)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label(
                        selectedImageData == nil ? "Choose Image" : "Choose Another Image",
                        systemImage: "photo.on.rectangle.angled"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 5) {
                    Text("The selected image is uploaded to SauceNAO to find its source. Hanairo does not store the image.")
                    Link(
                        "View SauceNAO Privacy Policy",
                        destination: URL(string: "https://saucenao.com/legal.html")!
                    )
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        } label: {
            Label("Choose an Image to Identify", systemImage: "photo.badge.magnifyingglass")
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        switch state {
        case .idle:
            ContentUnavailableView {
                Label("Find Source by Image", systemImage: "sparkle.magnifyingglass")
            } description: {
                Text("Choose a single complete, clear image without collage borders.")
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        case .loading:
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(statusMessage)
                    .font(.headline)
                Text("Identification usually takes a few seconds. Keep your network connected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        case let .failed(message):
            ContentUnavailableView {
                Label("Search Failed", systemImage: "photo.badge.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                if let selectedImageData {
                    Button("Retry") {
                        retrySearch(with: selectedImageData)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        case let .loaded(result):
            loadedContent(result)
        }
    }

    @ViewBuilder
    private func loadedContent(_ result: ReverseImageSearchResult) -> some View {
        if result.artworkIDs.isEmpty {
            ContentUnavailableView {
                Label("No Pixiv Artwork Found", systemImage: "photo.badge.magnifyingglass")
            } description: {
                Text("Try again with a more complete, clearer original image.")
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text("Results")
                    .font(.title2.weight(.bold))
                Spacer()
                Text("\(result.artworkIDs.count) candidates")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !result.illustrations.isEmpty {
                ArtworkGrid(illustrations: result.illustrations) { id in
                    await toggleBookmark(id: id, in: result)
                }
            }

            if !result.unavailableArtworkIDs.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.illustrations.isEmpty ? "Candidate Artworks" : "Other Candidate Artworks")
                        .font(.headline)
                    ForEach(result.unavailableArtworkIDs, id: \.self) { id in
                        NavigationLink(value: AppRoute.illustration(id: id)) {
                            HStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .frame(width: 28)
                                Text("Artwork ID \(id)")
                                    .font(.body.weight(.medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(14)
                            .background(
                                .quaternary,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )
    }

    private func search(_ item: PhotosPickerItem) async {
        let searchID = UUID()
        activeSearchID = searchID
        selectedImageData = nil
        statusMessage = "Reading and processing image…"
        state = .loading

        do {
            guard let originalData = try await item.loadTransferable(type: Data.self) else {
                throw ReverseImageSearchError.invalidImage
            }
            let jpegData = try await imageSearch.prepareJPEG(from: originalData)
            guard activeSearchID == searchID, !Task.isCancelled else { return }
            selectedImageData = jpegData
            await searchPreparedImage(jpegData, searchID: searchID)
        } catch is CancellationError {
            return
        } catch {
            guard activeSearchID == searchID else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func retrySearch(with jpegData: Data) {
        let searchID = UUID()
        activeSearchID = searchID
        Task {
            await searchPreparedImage(jpegData, searchID: searchID)
        }
    }

    private func searchPreparedImage(_ jpegData: Data, searchID: UUID) async {
        statusMessage = "Uploading to SauceNAO…"
        state = .loading
        do {
            let artworkIDs = try await imageSearch.searchPixivArtworkIDs(jpegData: jpegData)
            guard activeSearchID == searchID, !Task.isCancelled else { return }

            var illustrations: [PixivIllustration] = []
            if !artworkIDs.isEmpty {
                statusMessage = "Loading matching Pixiv artworks…"
                for artworkID in artworkIDs {
                    guard activeSearchID == searchID, !Task.isCancelled else { return }
                    do {
                        illustrations.append(try await repository.illustration(id: artworkID))
                    } catch is CancellationError {
                        return
                    } catch {
                        continue
                    }
                }
            }

            guard activeSearchID == searchID, !Task.isCancelled else { return }
            state = .loaded(
                ReverseImageSearchResult(
                    artworkIDs: artworkIDs,
                    illustrations: illustrations
                )
            )
        } catch is CancellationError {
            return
        } catch {
            guard activeSearchID == searchID else { return }
            state = .failed(error.localizedDescription)
        }
    }

    private func toggleBookmark(id: Int, in result: ReverseImageSearchResult) async {
        guard let illustration = result.illustrations.first(where: { $0.id == id }) else { return }
        do {
            _ = try await repository.toggleBookmark(illustration)
        } catch is CancellationError {
            return
        } catch {
            actionError = error.localizedDescription
        }
    }
}

private struct ReverseImageSearchResult {
    let artworkIDs: [Int]
    let illustrations: [PixivIllustration]

    var unavailableArtworkIDs: [Int] {
        let loadedIDs = Set(illustrations.map(\.id))
        return artworkIDs.filter { !loadedIDs.contains($0) }
    }
}

private struct ReverseImageSearchPreview: View {
    let data: Data

    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.quaternary)
            if let image {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Preview of image to identify")
        .task(id: data) {
            image = await Task.detached(priority: .userInitiated) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                    return nil
                }
                return CGImageSourceCreateImageAtIndex(source, 0, nil)
            }.value
        }
    }
}

#Preview("Reverse Image Search") {
    NavigationStack {
        ReverseImageSearchView()
    }
    .withPreviewDependencies()
}
