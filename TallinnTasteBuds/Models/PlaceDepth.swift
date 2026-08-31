import Foundation

/// How much of a place there is to look at, which is what its pin says:
/// something to watch, something to look at, or the write-up alone.
///
/// The site draws the same three readings, and the list carries them as words
/// beside the name — which is what makes every row a key to the map.
enum PlaceDepth {
    case reel      // there is a film of it
    case photos    // there are pictures of it
    case words     // the write-up, and that is all
}

extension Place {
    var depth: PlaceDepth {
        if reel != nil { return .reel }
        if !photos.isEmpty { return .photos }
        return .words
    }

    /// Instagram's word and TikTok's word are not the same word, and the rest
    /// of the map is careful about that, so the mark is too.
    var depthMarkKey: String {
        switch depth {
        case .reel: return isTikTok ? "markVideo" : "markReel"
        case .photos: return "markPhotos"
        case .words: return "markNone"
        }
    }

    /// A closed place is not one fact but two, and the second is the reason the
    /// entry is still here: the door is shut, and the reel is not. So the note
    /// says what is left rather than only what is gone.
    var closedNoteKey: String {
        switch depth {
        case .reel: return isTikTok ? "closedVideoNote" : "closedReelNote"
        case .photos: return "closedPhotosNote"
        case .words: return "closedNote"
        }
    }
}
