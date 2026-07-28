import AudioToolbox
import Foundation

public final class ExtAudioFileDecoder: AudioDecoder {
    private let fileRef: ExtAudioFileRef
    private let bytesPerSample: Int

    public let format: PCMFormat
    public let totalFrames: UInt64?

    public init(url: URL) throws {
        var fileRef: ExtAudioFileRef?
        try checkStatus(ExtAudioFileOpenURL(url as CFURL, &fileRef))
        guard let fileRef else {
            throw AudioDecoderError.failedToOpenFile("ExtAudioFileOpenURL produced no file reference")
        }

        var fileFormat = AudioStreamBasicDescription()
        var fileFormatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let getFormatStatus = ExtAudioFileGetProperty(fileRef, kExtAudioFileProperty_FileDataFormat, &fileFormatSize, &fileFormat)
        guard getFormatStatus == noErr else {
            ExtAudioFileDispose(fileRef)
            throw CoreAudioError.osStatus(getFormatStatus)
        }

        let bitDepth: Int
        do {
            bitDepth = try Self.sourceBitDepth(from: fileFormat)
        } catch {
            ExtAudioFileDispose(fileRef)
            throw error
        }
        let channelCount = Int(fileFormat.mChannelsPerFrame)

        let bytesPerSample = (bitDepth + 7) / 8
        var clientFormat = AudioStreamBasicDescription(
            mSampleRate: fileFormat.mSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: UInt32(bytesPerSample),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(bytesPerSample),
            mChannelsPerFrame: UInt32(channelCount),
            mBitsPerChannel: UInt32(bitDepth),
            mReserved: 0
        )
        let setFormatStatus = ExtAudioFileSetProperty(
            fileRef, kExtAudioFileProperty_ClientDataFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat
        )
        guard setFormatStatus == noErr else {
            ExtAudioFileDispose(fileRef)
            throw CoreAudioError.osStatus(setFormatStatus)
        }

        var totalFramesValue: Int64 = 0
        var totalFramesSize = UInt32(MemoryLayout<Int64>.size)
        let lengthStatus = ExtAudioFileGetProperty(fileRef, kExtAudioFileProperty_FileLengthFrames, &totalFramesSize, &totalFramesValue)

        self.fileRef = fileRef
        self.bytesPerSample = bytesPerSample
        self.format = PCMFormat(sampleRate: fileFormat.mSampleRate, bitDepth: bitDepth, channelCount: channelCount)
        self.totalFrames = (lengthStatus == noErr && totalFramesValue > 0) ? UInt64(totalFramesValue) : nil
    }

    deinit {
        ExtAudioFileDispose(fileRef)
    }

    private static func sourceBitDepth(from fileFormat: AudioStreamBasicDescription) throws -> Int {
        if fileFormat.mFormatID == kAudioFormatAppleLossless {
            switch fileFormat.mFormatFlags {
            case kAppleLosslessFormatFlag_16BitSourceData: return 16
            case kAppleLosslessFormatFlag_20BitSourceData: return 20
            case kAppleLosslessFormatFlag_24BitSourceData: return 24
            case kAppleLosslessFormatFlag_32BitSourceData: return 32
            default:
                throw AudioDecoderError.decodeError("unrecognized ALAC source bit depth flag \(fileFormat.mFormatFlags)")
            }
        }
        guard fileFormat.mBitsPerChannel > 0 else {
            throw AudioDecoderError.decodeError("file format reports 0 bits per channel")
        }
        return Int(fileFormat.mBitsPerChannel)
    }

    @discardableResult
    public func readFrames(into destination: PCMBuffer) throws -> Int {
        let channels = destination.channelCount
        let byteCount = destination.capacity * bytesPerSample

        let scratch = (0..<channels).map { _ in UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 1) }
        defer { for pointer in scratch { pointer.deallocate() } }

        let bufferList = AudioBufferList.allocate(maximumBuffers: channels)
        defer { free(bufferList.unsafeMutablePointer) }
        for channel in 0..<channels {
            bufferList[channel] = AudioBuffer(
                mNumberChannels: 1,
                mDataByteSize: UInt32(byteCount),
                mData: scratch[channel]
            )
        }

        var ioFrames = UInt32(destination.capacity)
        try checkStatus(ExtAudioFileRead(fileRef, &ioFrames, bufferList.unsafeMutablePointer))
        let framesRead = Int(ioFrames)

        let shift = (4 - bytesPerSample) * 8
        for channel in 0..<channels {
            let bytes = scratch[channel].assumingMemoryBound(to: UInt8.self)
            let out = destination.channelData[channel]
            for frame in 0..<framesRead {
                let offset = frame * bytesPerSample
                var raw: UInt32 = 0
                for byteIndex in 0..<bytesPerSample {
                    raw |= UInt32(bytes[offset + byteIndex]) << (8 * byteIndex)
                }
                out[frame] = Int32(bitPattern: raw << shift) >> shift
            }
        }
        destination.setFrameCount(framesRead)
        return framesRead
    }

    public func seek(toFrame frame: UInt64) throws {
        guard ExtAudioFileSeek(fileRef, Int64(frame)) == noErr else {
            throw AudioDecoderError.seekFailed
        }
    }
}
