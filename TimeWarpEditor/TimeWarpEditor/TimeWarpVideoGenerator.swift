//
//  TimeWarpVideoGenerator.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 3/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate
import CoreImage

// The denominator of a fractional approximation to a decimal number
let kPreferredTimeScale:Int32 = 64000

class ControlBlocks {
    var count:Int  // length of array (controls are indexes into this array)
    var size:Int   // block sizes
    var sampleRate:Float64 = 0
    var control:[Double] = []
    
    var timeWarpVideoGenerator:TimeWarpVideoGenerator
    
    var currentBlockIndex:Int = 0 // block start index into array of count `length` controls
    var lastCurrentBlockIndex:Int = -1
    
    init?(timeWarpVideoGenerator:TimeWarpVideoGenerator) {
        self.timeWarpVideoGenerator = timeWarpVideoGenerator
        
        let sampleRate = timeWarpVideoGenerator.sampleRate
        let count = timeWarpVideoGenerator.totalSampleCount
        let size = timeWarpVideoGenerator.outputBufferSize
        
        guard sampleRate > 0, count > 0, size > 0 else {
            return nil
        }
        
        self.sampleRate = sampleRate
        self.count = count
        self.size = size
    }
    
    var lastScaledTime:Double = 0
    var controlTime:Double = 0
    
    var audioIndex:Int = 0
    var controlIndex:Int = 0
    var lastPercent:CGFloat = 0
    var leftoverControls:[Double] = []
    
    func fillControls(range:ClosedRange<Int>) -> Int? {

        control.removeAll()
        control.append(contentsOf: leftoverControls)
        leftoverControls.removeAll()
        
        if audioIndex == 0 {
            controlIndex += 1
            
            if (controlIndex >= range.lowerBound && controlIndex <= range.upperBound) {
                control.append(0)
            }
        }
        
        while audioIndex <= count-1 {
            
            if timeWarpVideoGenerator.isCancelled { 
                return nil 
            }
            
            audioIndex += 1
            
            if audioIndex % Int(sampleRate) == 0 { // throttle rate of sending progress
                let percent = CGFloat(audioIndex)/CGFloat(count-1)
                timeWarpVideoGenerator.cumulativeProgress += ((percent - lastPercent) * timeWarpVideoGenerator.progressFactor)
                lastPercent = percent
                timeWarpVideoGenerator.progressAction(timeWarpVideoGenerator.cumulativeProgress, nil)
                print(timeWarpVideoGenerator.cumulativeProgress)
            }
            
            let time = Double(audioIndex) / sampleRate
            guard let scaledTime = timeWarpVideoGenerator.timeScale(time) else {
                return nil
            }
            
            if scaledTime > lastScaledTime {
                let timeRange = scaledTime - lastScaledTime
                
                controlTime = Double(controlIndex) / sampleRate
                while controlTime >= lastScaledTime, controlTime < scaledTime {
                    let fraction = (controlTime - lastScaledTime) / timeRange
                    
                    controlIndex += 1
                    
                    if (controlIndex >= range.lowerBound && controlIndex <= range.upperBound) {
                        control.append(Double(audioIndex-1) + fraction)
                    }
                    else if controlIndex > range.upperBound {
                        leftoverControls.append(Double(audioIndex-1) + fraction)
                    }
                    
                    controlTime = Double(controlIndex) / sampleRate
                    
                    if timeWarpVideoGenerator.isCancelled { 
                        return nil 
                    }
                }
            }
            
            lastScaledTime = scaledTime
            
            if controlIndex >= range.upperBound {
                break
            }
        }
        
        return controlIndex
    }
    
    func removeFirst() {
        currentBlockIndex += size
    }
    
    func first() -> [Double]? {
        
        if lastCurrentBlockIndex == currentBlockIndex {
            return control
        }
        
        lastCurrentBlockIndex = currentBlockIndex 
        
        let start = currentBlockIndex
        let end = currentBlockIndex + size
        
        guard let _ = fillControls(range: start...end-1) else {
            return nil
        }
        
        guard control.count > 0 else {
            return nil
        }
        
        return control
    }

}

class TimeWarpVideoGenerator : VideoWriter {

    var integrator: ((Double) -> Double)
    var videoDuration:Double = 0
    
        // audio time warping
    var outputBufferSize:Int = 0
    var channelCount:Int = 0
    var totalSampleCount:Int = 0
    var sourceFormat:CMFormatDescription?
    var sampleRate:Float64 = 0
    
        // video time warping
    var currentIndex:Int = 0
    var sampleBuffer:CMSampleBuffer?
    var sampleBufferPresentationTime = CMTime.zero
    var frameDuration:CMTime?
    var currentTime:CMTime = CMTime.zero
    
    var progressFactor:CGFloat = 1.0/3.0 // 3 contributors - only 1 if no audio
    var cumulativeProgress:CGFloat = 0
    
    var includeAudio: Bool
    
    var ciOrientationTransform:CGAffineTransform = CGAffineTransform.identity
    
    var timeWarpingLUT:[CGPoint] = []
    
    // error checking for time warping
    var lastPresentationTime:Double = -1
    var outOfOrder:Bool = false
    
    func timeScale(_ t:Double) -> Double?
    {     
        var resultValue:Double?
        
        resultValue = integrator(t/videoDuration)
        
        if let r = resultValue {
            resultValue = r * videoDuration
        }
        
        return resultValue
    }

        // MARK: Init and Start    
    init?(asset: AVAsset, frameRate: Int32, includeAudio: Bool, destination: String, integrator:@escaping (Double) -> Double, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {
        
        self.integrator = integrator
        
        if frameRate > 0 { // we are resampling
            let scale:Int32 = 600
            self.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate)).convertScale(scale, method: CMTimeRoundingMethod.default)
        }
        
        self.includeAudio = includeAudio 
        
        super.init(asset: asset, destination: destination, progress: progress, completion: completion)
        
        self.videoDuration = self.videoAsset.duration.seconds
        
        ciOrientationTransform = videoAsset.ciOrientationTransform()
        
        if let outputSettings = audioReaderSettings(),
           let sampleBuffer = self.videoAsset.audioSampleBuffer(outputSettings:outputSettings),
           let sampleBufferSourceFormat = CMSampleBufferGetFormatDescription(sampleBuffer),
           let audioStreamBasicDescription = sampleBufferSourceFormat.audioStreamBasicDescription
        {
            outputBufferSize = sampleBuffer.numSamples
            channelCount = Int(audioStreamBasicDescription.mChannelsPerFrame)
            totalSampleCount = self.videoAsset.audioBufferAndSampleCounts(outputSettings).sampleCount
            sourceFormat = sampleBufferSourceFormat
            sampleRate = audioStreamBasicDescription.mSampleRate
        }
        else {
            progressFactor = 1
        }
    }
    
    convenience init?(path: String, frameRate: Int32, includeAudio: Bool, destination: String, integrator:@escaping (Double) -> Double, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {
        
        let videoURL = URL(fileURLWithPath: path)
        let videoAsset = AVURLAsset(url: videoURL)
        
        self.init(asset: videoAsset, frameRate: frameRate, includeAudio: includeAudio, destination: destination, integrator: integrator, progress: progress, completion: completion)
    }
    
    deinit {
        print("TimeWarpVideoGenerator deinited")
    }
    
    // MARK: Override Reader And Writer Settings
        // Read uncompressed video buffers to modify presentation times
    
        // For HDR input specify SDR color properties in the videoReaderSettings
    func isHDR() -> Bool {
        let hdrTracks = videoAsset.tracks(withMediaCharacteristic: .containsHDRVideo) 
        return hdrTracks.count > 0
    }
    
        // Read LinearPCM for audio samples 
    override func audioReaderSettings() -> [String : Any]? {
        return [
            AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
            AVLinearPCMBitDepthKey: 16 as AnyObject,
            AVLinearPCMIsBigEndianKey: false as AnyObject,
            AVLinearPCMIsFloatKey: false as AnyObject,
            AVLinearPCMIsNonInterleaved: false as AnyObject]
    }
    
        // Write LinearPCM
    override func audioWriterSettings() -> [String : Any]? {
        return [AVFormatIDKey: kAudioFormatLinearPCM] as [String : Any]
    }
    
        // MARK: Video Writing
    
        // MARK: Resampling
    func copyNextSampleBufferForResampling(lastPercent:CGFloat) -> CGFloat {
        
        self.sampleBuffer = nil
        
        guard let sampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() else {
            return lastPercent
        }
        
        self.sampleBuffer = sampleBuffer
        
        if self.videoReaderOutput.outputSettings != nil {
            var presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            let timeToScale:Double = presentationTimeStamp.seconds
            
            if let presentationTimeStampScaled = self.timeScale(timeToScale) {
                
                timeWarpingLUT.append(CGPoint(x: presentationTimeStampScaled, y: timeToScale))
                
                presentationTimeStamp = CMTimeMakeWithSeconds(presentationTimeStampScaled, preferredTimescale: kPreferredTimeScale)
                if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: presentationTimeStamp) {
                    self.sampleBufferPresentationTime = presentationTimeStamp
                    self.sampleBuffer = adjustedSampleBuffer
                }
                else {
                    self.sampleBuffer = nil
                }
            }
            else {
                self.sampleBuffer = nil
            }
        }
        
        self.currentIndex += 1
        
        let percent:CGFloat = min(CGFloat(self.currentIndex)/CGFloat(self.frameCount), 1.0)
        self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
        self.progressAction(self.cumulativeProgress, self.sampleBuffer?.ciimage()?.transformed(by:ciOrientationTransform))
        
        print(self.cumulativeProgress)
        
        return percent
    }
    
    func appendNextSampleBufferForResampling() -> Bool {
        
        var appended = false
        
        if let sampleBuffer = self.sampleBuffer {
            
            if self.currentTime != sampleBufferPresentationTime {
                if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: self.currentTime) {
                    appended = self.videoWriterInput.append(adjustedSampleBuffer)
                }
            }
            else {
                appended = self.videoWriterInput.append(sampleBuffer)
            }
        }
        
        return appended
    }
    
    func writeVideoOnQueueResampled(_ serialQueue: DispatchQueue) {
        
        guard self.videoReader.startReading() else {
            self.finishVideoWriting()
            return
        }
        
        var lastPercent:CGFloat = 0
        
        videoWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while self.videoWriterInput.isReadyForMoreMediaData, self.writingVideoFinished == false {
                
                if self.currentIndex == 0 {
                    lastPercent = self.copyNextSampleBufferForResampling(lastPercent: lastPercent)
                }
                
                guard self.isCancelled == false else {
                    self.videoReader?.cancelReading()
                    self.finishVideoWriting()
                    return
                }
                
                guard self.sampleBuffer != nil else {
                    self.finishVideoWriting()
                    return
                }
                
                autoreleasepool { () -> Void in
                    
                    if self.currentTime <= self.sampleBufferPresentationTime {
                        
                        if let frameDuration = self.frameDuration, self.appendNextSampleBufferForResampling() {
                            self.currentTime = CMTimeAdd(self.currentTime, frameDuration)
                        }
                        else {
                            self.sampleBuffer = nil
                        }
                    }
                    else {
                        lastPercent = self.copyNextSampleBufferForResampling(lastPercent: lastPercent)
                    }
                }
            }
        }
    }
    
        // MARK: Time Warping
    func writeVideoOnQueueScaled(_ serialQueue:DispatchQueue) {
        
        guard self.videoReader.startReading() else {
            self.finishVideoWriting()
            return
        }
        
        var lastPercent:CGFloat = 0
                
        videoWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while self.videoWriterInput.isReadyForMoreMediaData, self.writingVideoFinished == false {
                
                autoreleasepool { () -> Void in
                    
                    guard self.isCancelled == false else {
                        self.videoReader?.cancelReading()
                        self.finishVideoWriting()
                        return
                    }
                    
                    guard let sampleBuffer = self.videoReaderOutput?.copyNextSampleBuffer() else {
                        self.finishVideoWriting()
                        return
                    }
                    
                    var presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    
                    let timeToScale:Double = presentationTimeStamp.seconds
                    
                    if let presentationTimeStampScaled = self.timeScale(timeToScale) {
                        
                        guard presentationTimeStampScaled > self.lastPresentationTime else {
                            self.outOfOrder = true
                            self.videoReader?.cancelReading()
                            self.finishVideoWriting()
                            return
                        }
                        
                        self.lastPresentationTime = presentationTimeStampScaled
                        
                        self.timeWarpingLUT.append(CGPoint(x: presentationTimeStampScaled, y: timeToScale))
                        
                        presentationTimeStamp = CMTimeMakeWithSeconds(presentationTimeStampScaled, preferredTimescale: kPreferredTimeScale)
                        if let adjustedSampleBuffer = sampleBuffer.setTimeStamp(time: presentationTimeStamp) {
                            self.sampleBuffer = adjustedSampleBuffer
                        }
                        else {
                            self.sampleBuffer = nil
                        }
                    }
                    else {
                        self.sampleBuffer = nil
                    }
                    
                    guard let sampleBuffer = self.sampleBuffer, self.videoWriterInput.append(sampleBuffer) else {
                        self.videoReader?.cancelReading()
                        self.finishVideoWriting()
                        return
                    }
                    
                    self.currentIndex += 1
                    
                    let percent:CGFloat = min(CGFloat(self.currentIndex)/CGFloat(self.frameCount), 1.0)
                    self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
                    self.progressAction(self.cumulativeProgress, self.sampleBuffer?.ciimage()?.transformed(by:self.ciOrientationTransform))
                    lastPercent = percent
                    print(self.cumulativeProgress)
                    
                }
            }
        }
    }
    
        // MARK: Override writeVideoOnQueue
    override func writeVideoOnQueue(_ serialQueue: DispatchQueue) {
        if let _ = self.frameDuration {
            writeVideoOnQueueResampled(serialQueue)
        }
        else {
            writeVideoOnQueueScaled(serialQueue)
        }
    }

        // MARK: Audio Writing
    func extractSamples(_ sampleBuffer:CMSampleBuffer) -> [Int16]? {
        
        if let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) {
            
            let sizeofInt16 = MemoryLayout<Int16>.size
            
            let bufferLength = CMBlockBufferGetDataLength(dataBuffer)
            
            var data = [Int16](repeating: 0, count: bufferLength / sizeofInt16)
            
            CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: bufferLength, destination: &data)
            
            return data
        }
        
        return nil
    }
    
    func interleave_arrays(_ arrays:[[Int16]]) -> [Int16]? {
        
        guard arrays.count > 0 else { return nil }
        
        if arrays.count == 1 {
            return arrays[0]
        }
        
        var size = Int.max
        for m in 0...arrays.count-1 {
            size = min(size, arrays[m].count)
        }
        
        guard size > 0 else { return nil }
        
        let interleaved_length = size * arrays.count
        var interleaved:[Int16] = [Int16](repeating: 0, count: interleaved_length)
        
        var count:Int = 0
        for j in 0...size-1 {
            for i in 0...arrays.count-1 {
                interleaved[count] = arrays[i][j]
                count += 1
            }
        }
        
        return interleaved 
    }
    
    func sampleBufferForSamples(audioSamples:[Int16], channelCount:Int, formatDescription:CMAudioFormatDescription) -> CMSampleBuffer? {
        
        var sampleBuffer:CMSampleBuffer?
        
        let bytesInt16 = MemoryLayout<Int16>.stride
        let dataSize = audioSamples.count * bytesInt16
        
        var samplesBlock:CMBlockBuffer? 
        
        let memoryBlock:UnsafeMutableRawPointer = UnsafeMutableRawPointer.allocate(
            byteCount: dataSize,
            alignment: MemoryLayout<Int16>.alignment)
        
        let _ = audioSamples.withUnsafeBufferPointer { buffer in
            memoryBlock.initializeMemory(as: Int16.self, from: buffer.baseAddress!, count: buffer.count)
        }
        
        if CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault, 
            memoryBlock: memoryBlock, 
            blockLength: dataSize, 
            blockAllocator: nil, 
            customBlockSource: nil, 
            offsetToData: 0, 
            dataLength: dataSize, 
            flags: 0, 
            blockBufferOut:&samplesBlock
        ) == kCMBlockBufferNoErr, let samplesBlock = samplesBlock {
            
            let sampleCount = audioSamples.count / channelCount
            
            if CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: samplesBlock, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription, sampleCount: sampleCount, sampleTimingEntryCount: 0, sampleTimingArray: nil, sampleSizeEntryCount: 0, sampleSizeArray: nil, sampleBufferOut: &sampleBuffer) == noErr, let sampleBuffer = sampleBuffer {
                
                guard sampleBuffer.isValid, sampleBuffer.numSamples == sampleCount else {
                    return nil
                }
            }
        }
        
        return sampleBuffer
    }
    
        // MARK: Override createAudioWriterInput
    override func createAudioWriterInput() {
        
        var outputSettings = audioWriterSettings()
        if sourceFormat == nil {
            outputSettings = nil // no audio  
        }
        
        if assetWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.audio) {
            
            let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings:outputSettings, sourceFormatHint: sourceFormat)
            
            audioWriterInput.expectsMediaDataInRealTime = false
            
            if assetWriter.canAdd(audioWriterInput) {
                assetWriter.add(audioWriterInput)
                self.audioWriterInput = audioWriterInput
            }
        }
    }
    
        // MARK: Override writeAudioOnQueue
    override func writeAudioOnQueue(_ serialQueue:DispatchQueue) {
        
        if includeAudio == false {
            self.finishAudioWriting()
            return
        }
        
        guard let controlBlocks = ControlBlocks(timeWarpVideoGenerator: self) else {
            self.finishAudioWriting()
            return
        }
        
        guard let audioReader = self.audioReader, let audioWriterInput = self.audioWriterInput, let audioReaderOutput = self.audioReaderOutput, audioReader.startReading() else {
            self.finishAudioWriting()
            return
        }
        
        var arrays_to_scale = [[Int16]](repeating: [], count: channelCount)
        var scaled_array:[Int16] = []
        
        var nbrItemsRemoved:Int = 0
        var nbrItemsToRemove:Int = 0
        
        var block = controlBlocks.first()
        controlBlocks.removeFirst()
        
        func update_arrays_to_scale() {
            if nbrItemsToRemove > arrays_to_scale[0].count {
                
                nbrItemsRemoved += arrays_to_scale[0].count
                nbrItemsToRemove = nbrItemsToRemove - arrays_to_scale[0].count
                
                for i in 0...arrays_to_scale.count-1 {
                    arrays_to_scale[i].removeAll()
                }
            }
            else if nbrItemsToRemove > 0 {
                for i in 0...arrays_to_scale.count-1 {
                    arrays_to_scale[i].removeSubrange(0...nbrItemsToRemove-1)
                }
                nbrItemsRemoved += nbrItemsToRemove
                nbrItemsToRemove = 0
            }
        }
        
        func lastIndexAdjusted(_ array:[Double]) -> Int? {
            
            guard array.count > 0, let last = array.last else {
                return nil
            }
            
            var lastIndex = Int(trunc(last))
            if last - trunc(last) > 0 {
                lastIndex += 1
            }
            return lastIndex
        }
        
        func offsetBlock(_ block:[Double]?) -> [Double]? {
            if let block = block {
                return vDSP.add(-trunc(block[0]), block)
            }
            return nil
        }
        
        var lastPercent:CGFloat = 0
        var bufferSamplesCount:Int = 0
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            while audioWriterInput.isReadyForMoreMediaData, self.writingAudioFinished == false {
                
                guard self.isCancelled == false, self.outOfOrder == false else {
                    self.audioReader?.cancelReading()
                    self.finishAudioWriting()
                    return
                }
                
                if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                    
                    bufferSamplesCount += sampleBuffer.numSamples
                    
                    if let bufferSamples = self.extractSamples(sampleBuffer) {
                        
                        let channels = bufferSamples.extract_array_channels(channelCount: self.channelCount)
                        
                        for i in 0...arrays_to_scale.count-1 {
                            arrays_to_scale[i].append(contentsOf: channels[i])
                        }
                        
                        update_arrays_to_scale()
                        
                        while true {
                            if let controlBlockOffset = offsetBlock(block), let indexAdjusted = lastIndexAdjusted(controlBlockOffset), indexAdjusted < arrays_to_scale[0].count {
                                
                                var scaled_channels:[[Int16]] = [] 
                                for array_to_scale in arrays_to_scale {
                                    scaled_channels.append(array_to_scale.scaleToD(control: controlBlockOffset))
                                }
                                
                                if let scaled_channels_interleaved = self.interleave_arrays(scaled_channels) {
                                    scaled_array.append(contentsOf: scaled_channels_interleaved)
                                }
                                
                                block = controlBlocks.first()
                                
                                if let controlBlock = block {
                                    
                                    let controlBlockIndex = Int(trunc(controlBlock[0]))
                                    
                                    nbrItemsToRemove = nbrItemsToRemove + (controlBlockIndex - nbrItemsRemoved)
                                    
                                    update_arrays_to_scale()
                                    
                                    controlBlocks.removeFirst()
                                }
                            }
                            else {
                                break
                            }
                        }
                        
                        if scaled_array.count > 0 {
                            if let sourceFormat = self.sourceFormat, let scaledBuffer = self.sampleBufferForSamples(audioSamples: scaled_array, channelCount: self.channelCount, formatDescription: sourceFormat), audioWriterInput.append(scaledBuffer) == true {
                                scaled_array.removeAll()
                            }
                            else {
                                audioReader.cancelReading()
                            }
                        }
                    }
                    
                    let percent = Double(bufferSamplesCount)/Double(self.totalSampleCount)
                    self.cumulativeProgress += ((percent - lastPercent) * self.progressFactor)
                    lastPercent = percent
                    self.progressAction(self.cumulativeProgress, nil)
                    
                    print(self.cumulativeProgress)
                }
                else {
                    self.finishAudioWriting()
                }
            }
        }
    }
}

