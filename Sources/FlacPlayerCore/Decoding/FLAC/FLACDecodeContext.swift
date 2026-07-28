@preconcurrency import CFLAC

final class FLACDecodeContext {
    var format: PCMFormat?
    var totalFrames: UInt64?
    var pendingBuffer: PCMBuffer?
    var pendingReadOffset: Int = 0
    var lastError: String?
}

func flacMetadataCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ metadata: UnsafePointer<FLAC__StreamMetadata>?,
    _ clientData: UnsafeMutableRawPointer?
) {
    guard let metadata, let clientData else { return }
    guard metadata.pointee.type == FLAC__METADATA_TYPE_STREAMINFO else { return }

    let context = Unmanaged<FLACDecodeContext>.fromOpaque(clientData).takeUnretainedValue()
    let info = metadata.pointee.data.stream_info
    context.format = PCMFormat(
        sampleRate: Double(info.sample_rate),
        bitDepth: Int(info.bits_per_sample),
        channelCount: Int(info.channels)
    )
    context.totalFrames = info.total_samples == 0 ? nil : info.total_samples
}

func flacErrorCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ status: FLAC__StreamDecoderErrorStatus,
    _ clientData: UnsafeMutableRawPointer?
) {
    guard let clientData else { return }
    let context = Unmanaged<FLACDecodeContext>.fromOpaque(clientData).takeUnretainedValue()
    context.lastError = describe(status)
}

func describe(_ status: FLAC__StreamDecoderErrorStatus) -> String {
    switch status {
    case FLAC__STREAM_DECODER_ERROR_STATUS_LOST_SYNC:
        return "lost sync"
    case FLAC__STREAM_DECODER_ERROR_STATUS_BAD_HEADER:
        return "bad header"
    case FLAC__STREAM_DECODER_ERROR_STATUS_FRAME_CRC_MISMATCH:
        return "frame CRC mismatch"
    case FLAC__STREAM_DECODER_ERROR_STATUS_UNPARSEABLE_STREAM:
        return "unparseable stream"
    case FLAC__STREAM_DECODER_ERROR_STATUS_BAD_METADATA:
        return "bad metadata"
    case FLAC__STREAM_DECODER_ERROR_STATUS_OUT_OF_BOUNDS:
        return "out of bounds"
    default:
        return "unknown decoder error (\(status.rawValue))"
    }
}

func describe(_ status: FLAC__StreamDecoderInitStatus) -> String {
    switch status {
    case FLAC__STREAM_DECODER_INIT_STATUS_OK:
        return "ok"
    case FLAC__STREAM_DECODER_INIT_STATUS_UNSUPPORTED_CONTAINER:
        return "unsupported container"
    case FLAC__STREAM_DECODER_INIT_STATUS_INVALID_CALLBACKS:
        return "invalid callbacks"
    case FLAC__STREAM_DECODER_INIT_STATUS_MEMORY_ALLOCATION_ERROR:
        return "memory allocation error"
    case FLAC__STREAM_DECODER_INIT_STATUS_ERROR_OPENING_FILE:
        return "error opening file"
    case FLAC__STREAM_DECODER_INIT_STATUS_ALREADY_INITIALIZED:
        return "already initialized"
    default:
        return "unknown init status (\(status.rawValue))"
    }
}

func flacWriteCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ frame: UnsafePointer<FLAC__Frame>?,
    _ buffer: UnsafePointer<UnsafePointer<Int32>?>?,
    _ clientData: UnsafeMutableRawPointer?
) -> FLAC__StreamDecoderWriteStatus {
    guard let frame, let buffer, let clientData else {
        return FLAC__STREAM_DECODER_WRITE_STATUS_ABORT
    }
    let context = Unmanaged<FLACDecodeContext>.fromOpaque(clientData).takeUnretainedValue()
    let header = frame.pointee.header
    let channelCount = Int(header.channels)
    let frameCount = Int(header.blocksize)

    let pcm = PCMBuffer(channelCount: channelCount, capacity: frameCount)
    for channel in 0..<channelCount {
        guard let channelPointer = buffer[channel] else { continue }
        pcm.channelData[channel].update(from: channelPointer, count: frameCount)
    }
    pcm.setFrameCount(frameCount)

    context.pendingBuffer = pcm
    context.pendingReadOffset = 0
    return FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
}
