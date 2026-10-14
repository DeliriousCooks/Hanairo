import ImageIO
import SwiftUI

struct LocalImageView: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: CGImage?
    @State private var didFail = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else if didFail {
                    Color.gray.opacity(0.28)
                        .accessibilityLabel("Failed to read local image")
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Reading local image")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .clipped()
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        image = nil
        didFail = false
        guard let url else {
            didFail = true
            return
        }
        let loadedImage: CGImage? = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }.value
        guard !Task.isCancelled, self.url == url else { return }
        image = loadedImage
        didFail = loadedImage == nil
    }
}
