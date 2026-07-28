@preconcurrency import CFLAC
import Foundation

public final class FLACDecoder: AudioDecoder {
    private let decoderPtr: UnsafeMutablePointer<FLAC__StreamDecoder>
    private let context: FLACDecodeContext

    public let format: PCMFormat
    public let totalFrames: UInt64?

    public init(url: URL) throws {
        guard let dec = FLAC__stream_decoder_new() else {
            throw AudioDecoderError.failedToCreateDecoder
        }

        let context = FLACDecodeContext()
        let contextPtr = Unmanaged.passUnretained(context).toOpaque()

        let cPath = strdup(url.path)
        defer { free(cPath) }
        let initStatus = FLAC__stream_decoder_init_file(dec, cPath, flacWriteCallback, flacMetadataCallback, flacErrorCallback, contextPtr)
        guard initStatus == FLAC__STREAM_DECODER_INIT_STATUS_OK else {
            FLAC__stream_decoder_delete(dec)
            throw AudioDecoderError.failedToOpenFile(describe(initStatus))
        }

        guard FLAC__stream_decoder_process_until_end_of_metadata(dec) != 0, let format = context.format else {
            let message = context.lastError ?? "no STREAMINFO block found"
            FLAC__stream_decoder_finish(dec)
            FLAC__stream_decoder_delete(dec)
            throw AudioDecoderError.decodeError(message)
        }

        self.decoderPtr = dec
        self.context = context
        self.format = format
        self.totalFrames = context.totalFrames
    }

    deinit {
        FLAC__stream_decoder_finish(decoderPtr)
        FLAC__stream_decoder_delete(decoderPtr)
    }

    @discardableResult
    public func readFrames(into destination: PCMBuffer) throws -> Int {
        var written = 0
        while written < destination.capacity {
            if context.pendingBuffer == nil || context.pendingReadOffset >= (context.pendingBuffer?.frameCount ?? 0) {
                context.pendingBuffer = nil
                context.pendingReadOffset = 0

                if FLAC__stream_decoder_get_state(decoderPtr) == FLAC__STREAM_DECODER_END_OF_STREAM {
                    break
                }
                guard FLAC__stream_decoder_process_single(decoderPtr) != 0 else {
                    if let message = context.lastError {
                        throw AudioDecoderError.decodeError(message)
                    }
                    break
                }
                if context.pendingBuffer == nil {
                    continue
                }
            }

            guard let pending = context.pendingBuffer else { break }
            let available = pending.frameCount - context.pendingReadOffset
            let toCopy = min(available, destination.capacity - written)
            let channels = min(destination.channelCount, pending.channelCount)
            for channel in 0..<channels {
                destination.channelData[channel].advanced(by: written)
                    .update(from: pending.channelData[channel].advanced(by: context.pendingReadOffset), count: toCopy)
            }
            context.pendingReadOffset += toCopy
            written += toCopy
        }
        destination.setFrameCount(written)
        return written
    }

    public func seek(toFrame frame: UInt64) throws {
        context.pendingBuffer = nil
        context.pendingReadOffset = 0
        guard FLAC__stream_decoder_seek_absolute(decoderPtr, frame) != 0 else {
            throw AudioDecoderError.seekFailed
        }
    }
}
