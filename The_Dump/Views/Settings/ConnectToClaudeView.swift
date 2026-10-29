import SwiftUI

/// "Use your notes in Claude": the setup screen for connecting The Dump to
/// Claude through the hosted MCP server. Connecting happens inside Claude, so
/// this screen only hands over the address and shows where to paste it; the
/// web guide (thedump.ai/mcp) covers everything else. Design: Paper file
/// The_Dump_Onboarding, page "App — Connect to Claude" (THEDUMP-135).
///
/// Opened from Settings (pushed), and as a sheet from the capture screen's
/// AI-chat tip and the last onboarding screen (`showsDoneButton`).
struct ConnectToClaudeView: View {
    var showsDoneButton = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                address
                    .padding(.top, 36)
                steps
                    .padding(.top, 40)
                whereItWorks
                    .padding(.top, 44)
                trySaying
                    .padding(.top, 44)
                actions
                    .padding(.top, 48)
            }
            .padding(.horizontal, Theme.screenH)
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Use your notes in Claude")
                .font(.system(size: 40, weight: .regular))
                .tracking(40 * -0.04)
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Connect The Dump once, then ask Claude to save a chat here or to look through your notes for you.")
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var address: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("The Dump's address")
            HStack(spacing: 12) {
                Text("\(Text("https://").foregroundColor(Theme.textSecondary))\(Text("mcp.thedump.ai/mcp").foregroundColor(Theme.textPrimary))")
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                Button(action: copyAddress) {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 13, weight: .semibold))
                        Text(copied ? "Copied" : "Copy")
                            .font(.system(size: Theme.fontSizeSM, weight: .medium))
                    }
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.textPrimary))
                }
                .accessibilityLabel(copied ? "Address copied" : "Copy address")
            }
            .padding(.leading, 18)
            .padding(.trailing, 12)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionLabel("Add it to Claude, one time")
            stepRow(1) {
                Text("Open **claude.ai** or the Claude desktop app, and go to **Customize → Connectors**.")
                    .stepText()
            }
            stepRow(2) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose **Add custom connector**, name it The Dump, and paste the address.")
                        .stepText()
                    ClaudeConnectorSketch()
                }
            }
            stepRow(3) {
                Text("Claude opens The Dump. Sign in as usual and choose **Allow**. You only do this once.")
                    .stepText()
            }
        }
    }

    private var whereItWorks: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Where it works")
                .padding(.bottom, 6)
            worksRow("Claude, web and desktop", "Steps above")
            worksRow("Claude on your phone", "After step 3")
            worksRow("Claude Code", "Full guide")
            worksRow("Cursor and other apps", "Full guide")
        }
    }

    private var trySaying: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Then try saying")
                .padding(.bottom, 4)
            Group {
                Text("“Save this conversation to The Dump”")
                Text("“What’s on my to-do list?”")
            }
            .font(.system(size: 20))
            .tracking(20 * -0.01)
            .foregroundColor(Theme.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: 18) {
            if let guide = URL(string: SharedConstants.mcpSetupGuideURL) {
                // The share sheet carries the guide's link, so people can
                // email or AirDrop it to the computer they set Claude up on.
                ShareLink(
                    item: guide,
                    subject: Text("Connect The Dump to Claude"),
                    message: Text("Set up The Dump in Claude: \(guide.absoluteString)")
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Send setup to my computer")
                            .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                    }
                    .foregroundColor(Theme.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Capsule().fill(Theme.textPrimary))
                }

                Button("Open the full guide →") { openURL(guide) }
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    // MARK: Pieces

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .medium))
            .tracking(11 * 0.12)
            .foregroundColor(Theme.textSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func stepRow<Content: View>(_ number: Int, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.textPrimary)
                .frame(width: 24, height: 24)
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                .accessibilityLabel("Step \(number)")
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func worksRow(_ name: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(name)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textPrimary)
            Spacer(minLength: 0)
            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.border).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func copyAddress() {
        UIPasteboard.general.string = SharedConstants.mcpServerURL
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

/// A simplified, untappable sketch of Claude's "Add custom connector" box with
/// The Dump's details filled in, so people recognise the box when they see it.
/// Always light, like Claude's own box.
private struct ClaudeConnectorSketch: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add custom connector")
                .font(.system(size: 13, weight: .semibold))
            VStack(spacing: 6) {
                field("The Dump", borderColor: Color(hex: "D1D1D6"), lineWidth: 1, monospaced: false)
                field(SharedConstants.mcpServerURL, borderColor: Color(hex: "1C1C1E"), lineWidth: 1.5, monospaced: true)
            }
            HStack {
                Spacer()
                Text("Add")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color(hex: "1C1C1E")))
            }
        }
        .foregroundColor(Color(hex: "1C1C1E"))
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "F5F5F7"))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, lineWidth: 1))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude's Add custom connector box, with the name The Dump and the address filled in")
    }

    private func field(_ text: String, borderColor: Color, lineWidth: CGFloat, monospaced: Bool) -> some View {
        Text(text)
            .font(.system(size: monospaced ? 11 : 12, design: monospaced ? .monospaced : .default))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(borderColor, lineWidth: lineWidth))
            )
    }
}

private extension Text {
    func stepText() -> some View {
        self.font(.system(size: Theme.fontSizeMD))
            .foregroundColor(Theme.textPrimary)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    NavigationStack {
        ConnectToClaudeView(showsDoneButton: true)
    }
}
