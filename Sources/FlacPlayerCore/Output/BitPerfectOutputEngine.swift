import AudioToolbox

public enum OutputEngineError: Error, Equatable {
    case componentNotFound
}

public final class BitPerfectOutputEngine {
    private var audioUnit: AudioUnit?
    private var decodeWorker: DecodeWorker?
    private let renderContext = RenderContext()

    public init() {}

    deinit {
        stop()
        if let unit = audioUnit {
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
        }
    }

    public func configure(
        device: OutputDevice,
        decoder: AudioDecoder,
        nextDecoderProvider: (() -> AudioDecoder?)? = nil,
        onFinished: (() -> Void)? = nil
    ) throws {
        stop()
        if let existing = audioUnit {
            AudioUnitUninitialize(existing)
            AudioComponentInstanceDispose(existing)
            audioUnit = nil
        }

        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw OutputEngineError.componentNotFound
        }

        var unit: AudioUnit?
        try checkStatus(AudioComponentInstanceNew(component, &unit))
        guard let unit else { throw OutputEngineError.componentNotFound }

        var enableOutput: UInt32 = 1
        try checkStatus(AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0,
            &enableOutput, UInt32(MemoryLayout<UInt32>.size)
        ))
        var disableInput: UInt32 = 0
        try checkStatus(AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1,
            &disableInput, UInt32(MemoryLayout<UInt32>.size)
        ))

        var deviceID = device.id
        try checkStatus(AudioUnitSetProperty(
            unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0,
            &deviceID, UInt32(MemoryLayout<AudioObjectID>.size)
        ))

        let format = decoder.format
        let channels = UInt32(format.channelCount)
        var streamFormat = AudioStreamBasicDescription(
            mSampleRate: format.sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4 * channels,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4 * channels,
            mChannelsPerFrame: channels,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        try checkStatus(AudioUnitSetProperty(
            unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0,
            &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        ))

        let ringBuffer = PCMRingBuffer(channelCount: format.channelCount, capacity: Int(format.sampleRate))
        renderContext.ringBuffer = ringBuffer
        renderContext.channelCount = format.channelCount
        renderContext.sourceBitDepth = format.bitDepth
        renderContext.scratch = PCMBuffer(channelCount: format.channelCount, capacity: 16384)
        renderContext.equalizer.setChannelCount(format.channelCount)
        renderContext.playedFrames.set(0)

        var callbackStruct = AURenderCallbackStruct(
            inputProc: renderCallback,
            inputProcRefCon: Unmanaged.passUnretained(renderContext).toOpaque()
        )
        try checkStatus(AudioUnitSetProperty(
            unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0,
            &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        ))

        try checkStatus(AudioUnitInitialize(unit))
        audioUnit = unit

        let context = renderContext
        let worker = DecodeWorker(
            decoder: decoder,
            ringBuffer: ringBuffer,
            nextDecoderProvider: nextDecoderProvider,
            onFinished: onFinished,
            onSeeked: { frame in context.playedFrames.set(frame) }
        )
        worker.start()
        decodeWorker = worker
    }

    public func start() throws {
        guard let unit = audioUnit else { throw OutputEngineError.componentNotFound }
        try checkStatus(AudioOutputUnitStart(unit))
    }

    public func pause() {
        guard let unit = audioUnit else { return }
        AudioOutputUnitStop(unit)
    }

    public func resume() throws {
        guard let unit = audioUnit else { throw OutputEngineError.componentNotFound }
        try checkStatus(AudioOutputUnitStart(unit))
    }

    public func stop() {
        decodeWorker?.stop()
        decodeWorker = nil
        if let unit = audioUnit {
            AudioOutputUnitStop(unit)
        }
    }

    public func setGain(_ gain: Float) {
        renderContext.gain.set(gain)
    }

    public func updateEqualizerBands(_ bands: [EQBand], sampleRate: Double) {
        renderContext.equalizer.updateBands(bands, sampleRate: sampleRate)
    }

    public func setEqualizerEnabled(_ enabled: Bool) {
        renderContext.equalizer.setEnabled(enabled)
    }

    public var playedFrames: UInt64 {
        renderContext.playedFrames.get()
    }

    public func seek(toFrame frame: UInt64) {
        decodeWorker?.requestSeek(toFrame: frame)
    }

    public var peakLevel: Float {
        renderContext.peakLevel.getAndReset()
    }
}

final class RenderContext {
    var ringBuffer: PCMRingBuffer?
    var scratch: PCMBuffer?
    var channelCount = 2
    var sourceBitDepth = 16
    let gain = AtomicFloat(1.0)
    let equalizer = EqualizerProcessor()
    let playedFrames = AtomicUInt64(0)
    let peakLevel = AtomicFloat(0)
}

func renderCallback(
    _ inRefCon: UnsafeMutableRawPointer,
    _ ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    _ inTimeStamp: UnsafePointer<AudioTimeStamp>,
    _ inBusNumber: UInt32,
    _ inNumberFrames: UInt32,
    _ ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let context = Unmanaged<RenderContext>.fromOpaque(inRefCon).takeUnretainedValue()
    guard let ioData, let ringBuffer = context.ringBuffer, let scratch = context.scratch else {
        return noErr
    }

    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    guard let audioBuffer = bufferList.first, let outRaw = audioBuffer.mData else { return noErr }
    let floatOut = outRaw.assumingMemoryBound(to: Float32.self)
    let channels = context.channelCount
    let framesRequested = min(Int(inNumberFrames), scratch.capacity)

    let framesRead = ringBuffer.read(into: scratch, maxFrames: framesRequested)
    if framesRead > 0 {
        context.playedFrames.add(UInt64(framesRead))
    }
    let scale = Float32(1 << (context.sourceBitDepth - 1))
    let gain = context.gain.get()
    let eqSnapshot = context.equalizer.prepareForRenderPass()

    var framePeak: Float32 = 0
    for frame in 0..<framesRead {
        for channel in 0..<channels {
            var sample = Float32(scratch.channelData[channel][frame]) / scale
            sample = context.equalizer.process(sample, channel: channel, snapshot: eqSnapshot)
            let output = sample * gain
            floatOut[frame * channels + channel] = output
            framePeak = max(framePeak, abs(output))
        }
    }
    for frame in framesRead..<framesRequested {
        for channel in 0..<channels {
            floatOut[frame * channels + channel] = 0
        }
    }
    context.peakLevel.accumulateMax(framePeak)
    return noErr
}
