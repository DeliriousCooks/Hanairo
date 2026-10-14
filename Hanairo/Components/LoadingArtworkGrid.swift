import SwiftUI

struct LoadingArtworkGrid: View {
    var body: some View {
        ProgressView("Loading artworks…")
            .frame(maxWidth: .infinity, minHeight: 320)
    }
}
