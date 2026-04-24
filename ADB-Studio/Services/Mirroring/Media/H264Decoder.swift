import Foundation
import CoreMedia
import VideoToolbox

final class H264Decoder {
    var onSampleBuffer: ((CMSampleBuffer) -> Void)?
    var onError: ((OSStatus) -> Void)?

    private var session: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var width: Int32
    private var height: Int32
    private var sps: Data?
    private var pps: Data?

    init?(width: Int, height: Int) {
        guard width > 0, height > 0 else { return nil }
        self.width = Int32(width)
        self.height = Int32(height)
    }

    deinit {
        invalidateSession()
    }

    func shutdown() {
        onSampleBuffer = nil
        onError = nil
        invalidateSession()
    }

    func recreate(width: Int, height: Int) {
        self.width = Int32(width)
        self.height = Int32(height)
        invalidateSession()
        formatDescription = nil
        sps = nil
        pps = nil
    }

    func feedConfig(_ csd: Data) {
        guard let (sps, pps) = Self.extractSPSPPS(fromAnnexB: csd) else {
            onError?(kVTVideoDecoderBadDataErr)
            return
        }
        self.sps = sps
        self.pps = pps

        if let fmtStatus = buildFormatDescription(sps: sps, pps: pps) {
            onError?(fmtStatus)
            return
        }
        if let sessionStatus = buildSession() {
            onError?(sessionStatus)
        }
    }

    func decode(naluData: Data, pts: Int64) {
        guard let session = session, let formatDescription = formatDescription else {
            return
        }

        let avccChunks = Self.annexBToAVCC(naluData)
        guard !avccChunks.isEmpty else { return }

        var payload = Data()
        for chunk in avccChunks {
            payload.append(chunk)
        }
        let payloadSize = payload.count

        var blockBuffer: CMBlockBuffer?
        let allocStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: payloadSize,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: payloadSize,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard allocStatus == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else {
            onError?(allocStatus)
            return
        }

        let copyStatus = payload.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.baseAddress else { return -1 }
            return CMBlockBufferReplaceDataBytes(
                with: base,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: payloadSize
            )
        }
        guard copyStatus == kCMBlockBufferNoErr else {
            onError?(copyStatus)
            return
        }

        var sampleBuffer: CMSampleBuffer?
        let sampleSizes = [payloadSize]
        var timings = [CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: CMTime(value: pts, timescale: 1_000_000),
            decodeTimeStamp: .invalid
        )]

        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timings,
            sampleSizeEntryCount: 1,
            sampleSizeArray: sampleSizes,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer = sampleBuffer else {
            onError?(sampleStatus)
            return
        }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [CFMutableDictionary],
           let dict = attachments.first {
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        var flagsOut: VTDecodeInfoFlags = []
        let decodeFlags: VTDecodeFrameFlags = [._EnableAsynchronousDecompression, ._EnableTemporalProcessing]

        let decodeStatus = VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sampleBuffer,
            flags: decodeFlags,
            frameRefcon: nil,
            infoFlagsOut: &flagsOut
        )

        if decodeStatus != noErr {
            onError?(decodeStatus)
        }
    }

    private func invalidateSession() {
        if let session = session {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
        }
        session = nil
    }

    private func buildFormatDescription(sps: Data, pps: Data) -> OSStatus? {
        var fmt: CMVideoFormatDescription?
        let status: OSStatus = sps.withUnsafeBytes { spsRaw -> OSStatus in
            pps.withUnsafeBytes { ppsRaw -> OSStatus in
                guard let spsBase = spsRaw.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let ppsBase = ppsRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return -1
                }
                let pointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                let sizes: [Int] = [sps.count, pps.count]
                return pointers.withUnsafeBufferPointer { ptrBuf in
                    sizes.withUnsafeBufferPointer { sizeBuf in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: ptrBuf.baseAddress!,
                            parameterSetSizes: sizeBuf.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &fmt
                        )
                    }
                }
            }
        }

        guard status == noErr, let fmt = fmt else {
            return status
        }
        self.formatDescription = fmt
        return nil
    }

    private func buildSession() -> OSStatus? {
        guard let formatDescription = formatDescription else {
            return kVTParameterErr
        }
        invalidateSession()

        let destinationAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var callback = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { decompressionRefcon, _, status, _, imageBuffer, pts, duration in
                guard let refcon = decompressionRefcon else { return }
                let decoder = Unmanaged<H264Decoder>.fromOpaque(refcon).takeUnretainedValue()
                decoder.handleDecodedFrame(status: status, imageBuffer: imageBuffer, pts: pts, duration: duration)
            },
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        var session: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: destinationAttributes as CFDictionary,
            outputCallback: &callback,
            decompressionSessionOut: &session
        )

        guard status == noErr, let session = session else {
            return status
        }

        VTSessionSetProperty(
            session,
            key: kVTDecompressionPropertyKey_RealTime,
            value: kCFBooleanTrue
        )

        self.session = session
        return nil
    }

    private func handleDecodedFrame(status: OSStatus, imageBuffer: CVImageBuffer?, pts: CMTime, duration: CMTime) {
        guard status == noErr else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(status)
            }
            return
        }
        guard let imageBuffer = imageBuffer else { return }

        var videoFormat: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &videoFormat
        )
        guard let videoFormat = videoFormat else { return }

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescription: videoFormat,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        guard createStatus == noErr, let sampleBuffer = sampleBuffer else {
            DispatchQueue.main.async { [weak self] in
                self?.onError?(createStatus)
            }
            return
        }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [CFMutableDictionary],
           let dict = attachments.first {
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        DispatchQueue.main.async { [weak self] in
            self?.onSampleBuffer?(sampleBuffer)
        }
    }

    static func extractSPSPPS(fromAnnexB csd: Data) -> (sps: Data, pps: Data)? {
        let nalus = annexBToAVCC(csd, stripLengthPrefix: true)
        guard nalus.count >= 2 else { return nil }

        var sps: Data?
        var pps: Data?
        for nalu in nalus {
            guard let firstByte = nalu.first else { continue }
            let nalType = firstByte & 0x1F
            if nalType == 7 {
                sps = nalu
            } else if nalType == 8 {
                pps = nalu
            }
        }
        guard let sps = sps, let pps = pps else { return nil }
        return (sps, pps)
    }

    static func annexBToAVCC(_ data: Data) -> [Data] {
        annexBToAVCC(data, stripLengthPrefix: false)
    }

    static func annexBToAVCC(_ data: Data, stripLengthPrefix: Bool) -> [Data] {
        let bytes = [UInt8](data)
        let count = bytes.count
        var starts: [Int] = []
        var i = 0
        while i < count - 3 {
            if bytes[i] == 0x00 && bytes[i + 1] == 0x00 && bytes[i + 2] == 0x00 && bytes[i + 3] == 0x01 {
                starts.append(i + 4)
                i += 4
                continue
            }
            if bytes[i] == 0x00 && bytes[i + 1] == 0x00 && bytes[i + 2] == 0x01 {
                starts.append(i + 3)
                i += 3
                continue
            }
            i += 1
        }
        var lengths: [Int] = []
        for index in 0..<starts.count {
            let end: Int
            if index + 1 < starts.count {
                let next = starts[index + 1]
                if next >= 4 && bytes[next - 4] == 0x00 && bytes[next - 3] == 0x00 && bytes[next - 2] == 0x00 && bytes[next - 1] == 0x01 {
                    end = next - 4
                } else {
                    end = next - 3
                }
            } else {
                end = count
            }
            lengths.append(end - starts[index])
        }
        var nalus: [Data] = []
        for (idx, start) in starts.enumerated() {
            let length = lengths[idx]
            guard length > 0 else { continue }
            let naluBody = data.subdata(in: start..<(start + length))
            if stripLengthPrefix {
                nalus.append(naluBody)
            } else {
                var avcc = Data(count: 4)
                avcc[0] = UInt8((length >> 24) & 0xFF)
                avcc[1] = UInt8((length >> 16) & 0xFF)
                avcc[2] = UInt8((length >> 8) & 0xFF)
                avcc[3] = UInt8(length & 0xFF)
                avcc.append(naluBody)
                nalus.append(avcc)
            }
        }
        return nalus
    }
}
