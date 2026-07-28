@preconcurrency import CFLAC

public enum FLACSanity {
    public static var libraryVersion: String {
        String(cString: FLAC__VERSION_STRING)
    }
}
