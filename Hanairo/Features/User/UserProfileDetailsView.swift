import SwiftUI

struct UserProfileDetailsView: View {
    let detail: PixivUserDetail

    @State private var showsWorkspace = false

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        content
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                content
            }
        } else {
            content
        }
#endif
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            FloatingGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.title3.weight(.bold))

                    Text(profileComment)
                        .font(.body)
                        .foregroundStyle(hasProfileComment ? .primary : .secondary)
                        .textSelection(.enabled)

                    if !profileRows.isEmpty || !profileLinks.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                    }

                    ForEach(profileRows, id: \.label) { row in
                        LabeledContent(row.label, value: row.value)
                    }
                    if !profileLinks.isEmpty {
                        profileLinkButtons
                    }
                }
                .font(.subheadline)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let workspace = detail.workspace, !workspaceRows(workspace).isEmpty {
                FloatingGlassCard {
                    VStack(spacing: 10) {
                        workspaceButton

                        if showsWorkspace {
                            VStack(spacing: 10) {
                                ForEach(workspaceRows(workspace), id: \.label) { row in
                                    LabeledContent(row.label, value: row.value)
                                }
                            }
                            .font(.subheadline)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var workspaceButton: some View {
        workspaceAction
            .buttonStyle(.plain)
    }

    private var workspaceAction: some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) {
                showsWorkspace.toggle()
            }
        } label: {
            HStack {
                Text("Workspace")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .rotationEffect(.degrees(showsWorkspace ? 180 : 0))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .accessibilityLabel(showsWorkspace ? "Collapse workspace" : "Expand workspace")
    }

    @ViewBuilder
    private var profileLinkButtons: some View {
#if os(visionOS)
        profileLinkButtons(usesGlass: false)
#else
        if #available(iOS 26.0, macOS 26.0, *) {
            profileLinkButtons(usesGlass: true)
        } else {
            profileLinkButtons(usesGlass: false)
        }
#endif
    }

    private func profileLinkButtons(usesGlass: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(profileLinks, id: \.url) { link in
                UserProfileLinkButton(link: link, usesGlass: usesGlass)
            }
        }
    }

    private var hasProfileComment: Bool {
        guard let comment = detail.user.comment else { return false }
        return !TextSanitizer.plainText(from: comment).isEmpty
    }

    private var profileComment: String {
        guard let comment = detail.user.comment else { return "This artist hasn't written a bio yet" }
        let plainText = TextSanitizer.plainText(from: comment)
        return plainText.isEmpty ? "This artist hasn't written a bio yet" : plainText
    }

    private var profileRows: [ProfileRow] {
        [
            profileRow(label: "Region", value: detail.profile.region),
            profileRow(label: "Occupation", value: detail.profile.job),
            profileRow(label: "Birthday", value: detail.profile.birth)
        ].compactMap { $0 }
    }

    private var profileLinks: [ProfileLink] {
        var links: [ProfileLink] = []
        if let url = detail.profile.webpage {
            links.append(ProfileLink(title: "Website", url: url))
        }
        if let url = detail.profile.twitterURL {
            let title = detail.profile.twitterAccount.map { "X / Twitter @\($0)" } ?? "X / Twitter"
            links.append(ProfileLink(title: title, url: url))
        }
        if let url = detail.profile.pawooURL {
            links.append(ProfileLink(title: "Pawoo", url: url))
        }
        return links
    }

    private func workspaceRows(_ workspace: PixivUserWorkspace) -> [ProfileRow] {
        [
            profileRow(label: "Computer", value: workspace.computer),
            profileRow(label: "Monitor", value: workspace.monitor),
            profileRow(label: "Tool", value: workspace.tool),
            profileRow(label: "Tablet", value: workspace.tablet),
            profileRow(label: "Music", value: workspace.music),
            profileRow(label: "Desk", value: workspace.desk),
            profileRow(label: "Chair", value: workspace.chair),
            profileRow(label: "Notes", value: workspace.comment)
        ].compactMap { $0 }
    }

    private func profileRow(label: String, value: String?) -> ProfileRow? {
        guard let value, !value.isEmpty else { return nil }
        return ProfileRow(label: label, value: value)
    }
}

private struct ProfileRow {
    let label: String
    let value: String
}

private struct ProfileLink {
    let title: String
    let url: URL
}

private struct UserProfileLinkButton: View {
    let link: ProfileLink
    let usesGlass: Bool

    @ViewBuilder
    var body: some View {
#if os(visionOS)
        fallback
#else
        if #available(iOS 26.0, macOS 26.0, *), usesGlass {
            linkView
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
        } else {
            fallback
        }
#endif
    }

    private var linkView: some View {
        Link(destination: link.url) {
            Label(link.title, systemImage: "arrow.up.right.square")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var fallback: some View {
        linkView
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
    }
}
