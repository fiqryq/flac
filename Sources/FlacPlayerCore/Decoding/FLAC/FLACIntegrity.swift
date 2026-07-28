@preconcurrency import CFLAC
import Foundation

public enum FLACIntegrityResult: Equatable, Sendable {
    case noChecksumStored
    case verified
    case mismatch
    case decodeError(String)
}

public enum FLACIntegrity {
    public static func verify(url: URL) -> FLACIntegrityResult {
        guard let dec = FLAC__stream_decoder_new() else {
            return .decodeError("failed to create decoder")
        }
        defer { FLAC__stream_decoder_delete(dec) }

        FLAC__stream_decoder_set_md5_checking(dec, 1)

        let context = FLACIntegrityContext()
        let contextPtr = Unmanaged.passUnretained(context).toOpaque()

        let cPath = strdup(url.path)
        defer { free(cPath) }

        let initStatus = FLAC__stream_decoder_init_file(
            dec, cPath, integrityWriteCallback, integrityMetadataCallback, integrityErrorCallback, contextPtr
        )
        guard initStatus == FLAC__STREAM_DECODER_INIT_STATUS_OK else {
            return .decodeError(describe(initStatus))
        }

        let decodedOK = FLAC__stream_decoder_process_until_end_of_stream(dec) != 0
        let matched = FLAC__stream_decoder_finish(dec) != 0

        guard decodedOK else {
            return .decodeError(context.lastError ?? "decode failed")
        }
        guard context.hasStoredMD5 else {
            return .noChecksumStored
        }
        return matched ? .verified : .mismatch
    }
}

final class FLACIntegrityContext {
    var hasStoredMD5 = false
    var lastError: String?
}

private func integrityWriteCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ frame: UnsafePointer<FLAC__Frame>?,
    _ buffer: UnsafePointer<UnsafePointer<Int32>?>?,
    _ clientData: UnsafeMutableRawPointer?
) -> FLAC__StreamDecoderWriteStatus {
    FLAC__STREAM_DECODER_WRITE_STATUS_CONTINUE
}

private func integrityMetadataCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ metadata: UnsafePointer<FLAC__StreamMetadata>?,
    _ clientData: UnsafeMutableRawPointer?
) {
    guard let metadata, let clientData else { return }
    guard metadata.pointee.type == FLAC__METADATA_TYPE_STREAMINFO else { return }
    let context = Unmanaged<FLACIntegrityContext>.fromOpaque(clientData).takeUnretainedValue()
    let md5 = metadata.pointee.data.stream_info.md5sum
    context.hasStoredMD5 = !isAllZero(md5)
}

private func integrityErrorCallback(
    _ decoder: UnsafePointer<FLAC__StreamDecoder>?,
    _ status: FLAC__StreamDecoderErrorStatus,
    _ clientData: UnsafeMutableRawPointer?
) {
    guard let clientData else { return }
    let context = Unmanaged<FLACIntegrityContext>.fromOpaque(clientData).takeUnretainedValue()
    context.lastError = describe(status)
}

private func isAllZero<T>(_ tuple: T) -> Bool {
    withUnsafeBytes(of: tuple) { buffer in buffer.allSatisfy { $0 == 0 } }
}
