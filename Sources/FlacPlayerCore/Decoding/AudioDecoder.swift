public enum AudioDecoderError: Error, Equatable {
    case failedToCreateDecoder
    case failedToOpenFile(String)
    case decodeError(String)
    case seekFailed
}

public protocol AudioDecoder: AnyObject {
    var format: PCMFormat { get }
    var totalFrames: UInt64? { get }

    @discardableResult
    func readFrames(into destination: PCMBuffer) throws -> Int

    func seek(toFrame frame: UInt64) throws
}
