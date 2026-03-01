import SwiftUI
import AVFoundation
import AVKit

struct OriginalAssetView: View {
    let asset: NoteAssetResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                Group {
                    if isImage {
                        imageViewer
                    } else if isAudio {
                        if let audioURL = URL(string: asset.signed_url) {
                            AudioAssetPlayerView(url: audioURL, filename: asset.filename)
                        } else {
                            VStack(spacing: Theme.spacingMD) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundColor(Theme.textSecondary)
                                Text("Invalid audio URL.")
                                    .font(.system(size: Theme.fontSizeSM))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                    } else {
                        fallbackView
                    }
                }
            }
            .navigationTitle("Original")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private var isImage: Bool {
        let ct = asset.content_type.lowercased()
        return ct.hasPrefix("image/") || ["jpg", "jpeg", "png", "gif", "webp", "heic", "heif", "bmp", "tiff"].contains(ct)
    }

    private var isAudio: Bool {
        let ct = asset.content_type.lowercased()
        return ct.hasPrefix("audio/") || ["mp3", "m4a", "wav", "aac", "ogg", "flac"].contains(ct)
    }

    // MARK: - Image Viewer

    @ViewBuilder
    private var imageViewer: some View {
        if let url = URL(string: asset.signed_url) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView("Loading image…")
                        .foregroundColor(Theme.textSecondary)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    VStack(spacing: Theme.spacingMD) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.textSecondary)
                        Text("Failed to load image.")
                            .font(.system(size: Theme.fontSizeSM))
                            .foregroundColor(Theme.textSecondary)
                    }
                @unknown default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Fallback (documents, PDFs, etc.)

    @ViewBuilder
    private var fallbackView: some View {
        VStack(spacing: Theme.spacingLG) {
            Image(systemName: "doc")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)

            Text(asset.filename)
                .font(.system(size: Theme.fontSizeMD))
                .foregroundColor(Theme.textPrimary)

            Text(asset.content_type)
                .font(.system(size: Theme.fontSizeSM))
                .foregroundColor(Theme.textSecondary)

            if let url = URL(string: asset.signed_url) {
                Link("Open in Browser", destination: url)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Theme.spacingLG)
    }
}

// MARK: - Audio Player

private struct AudioAssetPlayerView: View {
    let url: URL
    let filename: String

    @State private var player: AVPlayer?
    @State private var isPlaying = false

    var body: some View {
        VStack(spacing: Theme.spacingLG) {
            Spacer()

            Image(systemName: "waveform")
                .font(.system(size: 64))
                .foregroundColor(Theme.accent)

            Text(filename)
                .font(.system(size: Theme.fontSizeMD, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(Theme.accent)
            }

            Spacer()
        }
        .padding(Theme.spacingLG)
        .onAppear {
            let avPlayer = AVPlayer(url: url)
            self.player = avPlayer

            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)

            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: avPlayer.currentItem,
                queue: .main
            ) { _ in
                isPlaying = false
                avPlayer.seek(to: .zero)
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }

    private func togglePlayback() {
        guard let player else { return }

        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
}
