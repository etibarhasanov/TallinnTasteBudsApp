import AVFoundation
import Observation

/// The rail's radio button, natively: an audio stream from `data/radio.json`
/// that keeps playing while the phone is locked, which is the part a web page
/// on iOS cannot do.
@MainActor
@Observable
final class RadioPlayer {
    private(set) var isPlaying = false
    private(set) var failed = false
    private(set) var station: RadioStation?

    private var player: AVPlayer?

    func toggle(_ station: RadioStation?) {
        guard let station else { return }
        if isPlaying && self.station == station {
            stop()
        } else {
            play(station)
        }
    }

    /// Follow a language change while playing. `data/radio.json` gives most
    /// languages a station of their own, so the station is part of what the
    /// language picker chooses — leaving the old one playing would make the
    /// choice half-apply. Does nothing when the radio is off, or when both
    /// languages share a station and there is nothing to move to.
    func follow(_ station: RadioStation?) {
        guard isPlaying, let station, station != self.station else { return }
        play(station)
    }

    func play(_ station: RadioStation) {
        failed = false
        do {
            // .playback is what keeps the stream alive behind the lock screen and
            // stops it being cut short by the ringer switch.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            failed = true
            return
        }
        let player = AVPlayer(playerItem: AVPlayerItem(url: station.url))
        player.play()
        self.player = player
        self.station = station
        isPlaying = true

        // A dead stream fails asynchronously, so give it a moment and then ask
        // the player this object still holds — nothing non-Sendable travels.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.isPlaying,
                  self.player?.currentItem?.status == .failed else { return }
            self.stop()
            self.failed = true
        }
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
