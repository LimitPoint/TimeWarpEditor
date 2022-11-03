//
//  TimeWarpExtensions.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 8/25/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage
import Accelerate
#if os(iOS)
import UserNotifications
#endif // #if os(iOS)

extension Array where Element == Int16  {
    
    func scaleToD(control:[Double]) -> [Element] {
        
        let length = control.count
        
        guard length > 0 else {
            return []
        }
        
        let stride = vDSP_Stride(1)
        
        var result = [Double](repeating: 0, count: length)
        
        var double_array = vDSP.integerToFloatingPoint(self, floatingPointType: Double.self)
        
        let lastControl = control[control.count-1]
        let lastControlTrunc = Int(trunc(lastControl))
        if lastControlTrunc > self.count - 2 {
            let zeros = [Double](repeating: 0, count: lastControlTrunc - self.count + 2)
            double_array.append(contentsOf: zeros)
        }
        
        vDSP_vlintD(double_array,
                    control, stride,
                    &result, stride,
                    vDSP_Length(length),
                    vDSP_Length(double_array.count))
        
        return vDSP.floatingPointToInteger(result, integerType: Int16.self, rounding: .towardNearestInteger)
    }
    
    func extract_array_channel(channelIndex:Int, channelCount:Int) -> [Int16]? {
        
        guard channelIndex >= 0, channelIndex < channelCount, self.count > 0 else { return nil }
        
        let channel_array_length = self.count / channelCount
        
        guard channel_array_length > 0 else { return nil }
        
        var channel_array = [Int16](repeating: 0, count: channel_array_length)
        
        for index in 0...channel_array_length-1 {
            let array_index = channelIndex + index * channelCount
            channel_array[index] = self[array_index]
        }
        
        return channel_array
    }
    
    func extract_array_channels(channelCount:Int) -> [[Int16]] {
        
        var channels:[[Int16]] = []
        
        guard channelCount > 0 else { return channels }
        
        for channel_index in 0...channelCount-1 {
            if let channel = self.extract_array_channel(channelIndex: channel_index, channelCount: channelCount) {
                channels.append(channel)
            }
        }
        
        return channels
    }
}

extension CIImage {
    
    func cgimage() -> CGImage? {
        
        var cgImage:CGImage
        
        if let cgi = self.cgImage {
            cgImage = cgi
        }
        else {
            let context = CIContext(options: nil)
            guard let cgi = context.createCGImage(self, from: self.extent) else { return nil }
            cgImage = cgi
        }
        
        return cgImage
    }
}

extension CMSampleBuffer {
    
    func ciimage() -> CIImage? {
        
        var ciImage:CIImage?
        
        if let imageBuffer = CMSampleBufferGetImageBuffer(self) {
            ciImage = CIImage(cvImageBuffer: imageBuffer)
        }
        
        return ciImage
    }
    
    func setTimeStamp(time: CMTime) -> CMSampleBuffer? {
        var count: CMItemCount = 0
        
        guard CMSampleBufferGetSampleTimingInfoArray(self, entryCount: 0, arrayToFill: nil, entriesNeededOut: &count) == noErr, count == 1 else {
            return nil
        }
        
        let timingInfoArray = [CMSampleTimingInfo(duration: CMTime.invalid, presentationTimeStamp: time, decodeTimeStamp: CMTime.invalid)]
        
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: self, sampleTimingEntryCount: count, sampleTimingArray: timingInfoArray, sampleBufferOut: &sampleBuffer) == noErr else {
            return nil
        }
        return sampleBuffer
    }
}

extension AVAsset {
    
    func audioReader(outputSettings: [String : Any]?) -> (audioTrack:AVAssetTrack?, audioReader:AVAssetReader?, audioReaderOutput:AVAssetReaderTrackOutput?) {
        
        if let audioTrack = self.tracks(withMediaType: .audio).first {
            if let audioReader = try? AVAssetReader(asset: self)  {
                let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
                return (audioTrack, audioReader, audioReaderOutput)
            }
        }
        
        return (nil, nil, nil)
    }
    
    func videoReader(outputSettings: [String : Any]?) -> (videoTrack:AVAssetTrack?, videoReader:AVAssetReader?, videoReaderOutput:AVAssetReaderTrackOutput?) {
        
        if let videoTrack = self.tracks(withMediaType: .video).first {
            if let videoReader = try? AVAssetReader(asset: self)  {
                let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
                return (videoTrack, videoReader, videoReaderOutput)
            }
        }
        
        return (nil, nil, nil)
    }
    
    func audioSampleBuffer(outputSettings: [String : Any]?) -> CMSampleBuffer? {
        
        var buffer:CMSampleBuffer?
        
        if let audioTrack = self.tracks(withMediaType: .audio).first, let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            
            if audioReader.canAdd(audioReaderOutput) {
                audioReader.add(audioReaderOutput)
                
                if audioReader.startReading() {
                    buffer = audioReaderOutput.copyNextSampleBuffer()
                    
                    audioReader.cancelReading()
                }
            }
        }
        
        return buffer
    }
    
        // Note: the number of samples per buffer may change, resulting in different bufferCounts
    func audioBufferAndSampleCounts(_ outputSettings:[String : Any]) -> (bufferCount:Int, sampleCount:Int) {
        
        var sampleCount:Int = 0
        var bufferCount:Int = 0
        
        guard let audioTrack = self.tracks(withMediaType: .audio).first else {
            return (bufferCount, sampleCount)
        }
        
        if let audioReader = try? AVAssetReader(asset: self)  {
            
            let audioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
            audioReader.add(audioReaderOutput)
            
            if audioReader.startReading() {
                
                while audioReader.status == .reading {
                    if let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() {
                        sampleCount += sampleBuffer.numSamples
                        bufferCount += 1
                    }
                    else {
                        audioReader.cancelReading()
                    }
                }
            }
        }
        
        return (bufferCount, sampleCount)
    }
    
    func assetTrackTransform() -> CGAffineTransform? {
        guard let track = self.tracks(withMediaType: AVMediaType.video).first else { return nil }
        return track.preferredTransform
    }
    
    func estimatedFrameCount() -> Int {
        
        var frameCount = 0
        
        guard let videoTrack = self.tracks(withMediaType: .video).first else {
            return 0
        }
        
        frameCount = Int(CMTimeGetSeconds(self.duration) * Float64(videoTrack.nominalFrameRate))
        
        return frameCount
    }
    
    func ciOrientationTransform() -> CGAffineTransform {
        var orientationTransform = CGAffineTransform.identity
        if let videoTransform = self.assetTrackTransform() {
            orientationTransform = videoTransform.inverted()
        }
        return orientationTransform
    }
    
    func trimComposition(from:CMTime, to:CMTime) -> AVMutableComposition? {
        
        let videoTracks = self.tracks(withMediaType: AVMediaType.video)
        
        if videoTracks.count == 0 {
            return nil
        }
        
        let clipVideoTrack = videoTracks[0]
        
        let audioTracks = self.tracks(withMediaType: AVMediaType.audio)
        
        var clipAudioTrack:AVAssetTrack? = nil
        if audioTracks.count > 0 {
            clipAudioTrack = audioTracks[0]
        }
        
        let composition = AVMutableComposition()
        
        let range = CMTimeRange(start: from, end: to)
        
        if clipAudioTrack != nil {
            
            if let compositionAudioTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                
                compositionAudioTrack.preferredVolume = clipAudioTrack!.preferredVolume
                
                do {
                    try compositionAudioTrack.insertTimeRange(range, of: clipAudioTrack!, at: CMTime.zero)
                }
                catch {
                    
                }
            }
        }
        
        guard let compositionVideoTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        
        do {
            try compositionVideoTrack.insertTimeRange(range, of: clipVideoTrack, at: CMTime.zero)
        }
        catch {
            
        }
        
        compositionVideoTrack.preferredTransform = clipVideoTrack.preferredTransform
        
        return composition
    }
    
    class func secondsToString(secondsIn:Double) -> String {
        
        if CGFloat(secondsIn) > (CGFloat.greatestFiniteMagnitude / 2.0) {
            return "∞"
        }
        
        let secondsRounded = round(secondsIn)
        
        let hours:Int = Int(secondsRounded / 3600)
        
        let minutes:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 60))
            //let minutes:Int = Int(totalSeconds % 3600 / 60)
            //let seconds:Int = Int(totalSeconds % 60)
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
    
    func getCGImageAssetFrame(_ tolerance:CMTime, percent:Float) -> CGImage?
    {
        var imageRef:CGImage?
        
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true
        
        imageGenerator.requestedTimeToleranceAfter = tolerance
        imageGenerator.requestedTimeToleranceBefore = tolerance
        
        var time = self.duration
        
        time.value = Int64(Float(time.value) * percent)
        
        do {
            var actualTime = CMTime.zero
            imageRef = try imageGenerator.copyCGImage(at: time, actualTime:&actualTime)
        }
        catch let error as NSError
        {
            print("Image generation failed with error \(error)")
        }
        
        return imageRef
    }
    
}

extension FileManager {
    
        // Returns the url for Documents or a subdirectory named 'inSubdirectory' if not nil
    class func urlForDocumentsSubdirectory(inSubdirectory:String?) -> URL? {
        var documentsURL: URL?
        
        do {
            documentsURL = try FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        catch {
            return nil
        }
        
        guard let subdirectoryName = inSubdirectory else {
            return documentsURL
        }
        
        if let directoryURL = documentsURL?.appendingPathComponent(subdirectoryName) {
            if FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: nil) == false {
                do {
                    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes:nil)
                }
                catch let error as NSError {
                    print("error = \(error.description)")
                    return nil
                }
            }
            
            return directoryURL
        }
        
        return nil
    }
    
        // Returns the url for file 'filename' in Documents or a subdirectory named 'inSubdirectory' if not nil
    class func documentsURL(filename:String?, inSubdirectory:String?) -> URL? {
        
        guard let documentsDirectoryURL = FileManager.urlForDocumentsSubdirectory(inSubdirectory: inSubdirectory) else {
            return nil
        }
        
        var destinationURL = documentsDirectoryURL
        
        if let filename = filename {
            destinationURL = documentsDirectoryURL.appendingPathComponent(filename)
        }
        
        return destinationURL
    }
    
    class func clearDocuments() {
        FileManager.clear(directoryURL: FileManager.documentsURL(filename: nil, inSubdirectory: nil))
    }
    
    class func clear(directoryURL:URL?) {
        
        guard let directoryURL = directoryURL else {
            return
        }
        
        let fileManager = FileManager.default
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory( at: directoryURL, includingPropertiesForKeys: nil, options: [])
            for file in directoryContents {
                do {
                    try fileManager.removeItem(at: file)
                }
                catch let error as NSError {
                    debugPrint("Ooops! Something went wrong: \(error)")
                }
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
}

extension Bundle {
    var displayName: String? {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    }
}

#if os(iOS)
extension UNUserNotificationCenter {
    class func sendNotification(title:String, body:String, soundName:String, when:TimeInterval, repeats:Bool) {
        
        let id = UUID().uuidString
        
        let content = UNMutableNotificationContent()
        content.title = NSString.localizedUserNotificationString(forKey: title, arguments: nil)
        content.body = NSString.localizedUserNotificationString(forKey: body, arguments: nil)
        
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        
        content.categoryIdentifier = id
        
        let trigger = UNTimeIntervalNotificationTrigger.init(timeInterval: when, repeats: repeats)
        let request = UNNotificationRequest.init(identifier: id, content: content, trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        center.add(request) { (error) in
            
        }
    }
}
#endif // #if os(iOS)

