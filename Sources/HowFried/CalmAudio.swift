import AVFoundation
import Combine
import HowFriedCore

@MainActor final class CalmAudio: ObservableObject {
    @Published var playing = false
    @Published var loading = false
    @Published var title = ""
    @Published var error: String?
    private var player: AVAudioPlayer?
    private var generation = UUID()
    func play() {
        guard !loading, !playing else { return }
        loading = true; error = nil
        let variant = Int.random(in: 0..<CalmScore.titles.count), current = UUID()
        generation = current; title = CalmScore.titles[variant]
        Task {
            let data = await Task.detached(priority: .userInitiated) { CalmScore.wave(variant: variant) }.value
            guard generation == current else { return }
            do {
                let player = try AVAudioPlayer(data: data)
                player.numberOfLoops = -1
                // UI tests validate playback without making sound in the owner's workspace.
                player.volume = ProcessInfo.processInfo.environment["HOWFRIED_QA"] == "1" ? 0 : 0.30
                guard player.prepareToPlay(), player.play() else { throw CocoaError(.fileReadUnknown) }
                self.player = player; playing = true; loading = false
            } catch { loading = false; self.error = "Music unavailable. The break can stay quiet." }
        }
    }
    func stop() { generation = UUID(); player?.stop(); player = nil; playing = false; loading = false }
    deinit { player?.stop() }
}
