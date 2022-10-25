//
//  VideoWriter.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 3/22/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import AVFoundation
import CoreImage

#if os(iOS)
import UIKit
import UserNotifications
    // notification sounds
let kTimeWarpEditorSuccessSoundName = "TimeWarpEditorSuccessSoundName.m4a"
let kTimeWarpEditorWarningSoundName = "TimeWarpEditorWarningSoundName.m4a"
#endif // #if os(iOS)   

func testVideoWriter() {
    let fm = FileManager.default
    let docsurl = try! fm.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    
    let destinationPath = docsurl.appendingPathComponent("DefaultVideoCopy.mov").path
    let videoWriter = VideoWriter(path: kDefaultURL.path, destination: destinationPath, progress: { p, _ in
        print("p = \(p)")
    }, completion: { result, error in
        print("result = \(String(describing: result))")
    })
    
    videoWriter?.start()
}

/*
 
 Base class for reading and writing video: copies video using passthourgh read and write.
 
 TimeWarpVideoGenerator subclass overrides to read uncompressed video samples for processing to scale video and audio.
    
 */
class VideoWriter {
    
    var videoAsset:AVAsset
    var generatedMovieURL: URL
    
    var progressAction: ((CGFloat, CIImage?) -> Void) = { progress,_ in print("progress = \(progress)")}
    var completionAction: ((URL?, String?) -> Void) = { url,error in (url == nil ? print("Failed! - \(String(describing: error))") : print("Success!")) }
    
    var movieSize:CGSize
    
    var assetWriter:AVAssetWriter!
    
    var videoWriterInput:AVAssetWriterInput!
    var audioWriterInput:AVAssetWriterInput!
    
    var videoReader: AVAssetReader!
    var videoReaderOutput:AVAssetReaderTrackOutput!
    var audioReader: AVAssetReader?
    var audioReaderOutput:AVAssetReaderTrackOutput?
    
    var writingVideoFinished = false
    var writingAudioFinished = false
    
    var frameCount:Int = 0
    var currentFrameCount:Int = 0 // video
    
    let videoQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-video-generator-queue")
    let audioQueue: DispatchQueue = DispatchQueue(label: "com.limit-point.time-scale-audio-generator-queue")
    
    var isCancelled = false
    
        // MARK: Private - Backgroundable
#if os(iOS)    
    private var backgroundDescription:String
    private var reminderTimeInterval:Double = 60
    
    private var backgroundID = UIBackgroundTaskIdentifier.invalid
    
    private func backgroundTimeRemaining() -> TimeInterval {
        
        var timeIntervel:TimeInterval = 0
        
        let block = {
            timeIntervel = UIApplication.shared.backgroundTimeRemaining
        }
        
        if Thread.isMainThread {
            block()
        }
        else {
            DispatchQueue.main.sync {
                block()
            }
        }
        
        return timeIntervel
    }
    
    private func addNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willTerminateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc func appDidEnterBackground() {
        if (self.backgroundID != UIBackgroundTaskIdentifier.invalid) {
            
            UNUserNotificationCenter.sendNotification(title: self.backgroundDescription, body: "Return to the app soon to prevent failure.", soundName: kTimeWarpEditorWarningSoundName, when: self.reminderTimeInterval, repeats:false)
            
            print(self.backgroundDescription + " scheduled a notification in \(self.reminderTimeInterval) seconds.")
            
            let delayInSeconds = 2
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(delayInSeconds)) { [weak self] in
                
                if let timeRemaining = self?.backgroundTimeRemaining(), let backgroundDescription = self?.backgroundDescription {
                    print("TimeWarp entered background.")
                    print("TimeWarp has \(timeRemaining) seconds (\(timeRemaining/60) minutes) left in background.")
                    
                    let durationString = AVAsset.secondsToString(secondsIn: timeRemaining)
                    
                    UNUserNotificationCenter.sendNotification(title: "Warning", body: backgroundDescription + " can run for about \(durationString) in background.", soundName: kTimeWarpEditorWarningSoundName, when: 0.1, repeats:false)
                    
                }
            }
        }
    }
    
    @objc func appDidBecomeActive() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    @objc func appWillTerminate() {
        self.removeNotifications()
    }
#endif // #if os(iOS) 
    
    init?(asset: AVAsset, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {

#if os(iOS)            
        backgroundDescription = kVideoWriterBackgroundDescription
        if let displayName = Bundle.main.displayName {
            backgroundDescription = displayName
        }
#endif // #if os(iOS)   
        
        generatedMovieURL = URL(fileURLWithPath: destination)
        
        progressAction = progress
        completionAction = completion
        
        self.videoAsset = asset
        
        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            return nil
        }
        
        movieSize = CGSize(width: videoTrack.naturalSize.width, height: videoTrack.naturalSize.height)
        
        self.frameCount = videoAsset.estimatedFrameCount()
        
#if os(iOS)
        self.addNotifications()
#endif // #if os(iOS)   
    }
    
    convenience init?(path: String, destination: String, progress: @escaping (CGFloat, CIImage?) -> Void, completion: @escaping (URL?, String?) -> Void) {
        
        let videoURL = URL(fileURLWithPath: path)
        let videoAsset = AVURLAsset(url: videoURL)
        
        self.init(asset: videoAsset, destination: destination, progress: progress, completion: completion)
    }
    
    func start() {
        
        if FileManager.default.fileExists(atPath: generatedMovieURL.path) {
            try? FileManager.default.removeItem(at: generatedMovieURL)
        }

#if os(iOS)        
        self.backgroundID = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(self.backgroundID)
            self.backgroundID = UIBackgroundTaskIdentifier.invalid
        })
#endif // #if os(iOS)  
        
        createAssetWriter()
        
        prepareForReading()
        prepareForWriting()
        
        startAssetWriter()
        
        writeVideoAndAudio()
    }
    
        // VideoWriter is passthough
    func videoReaderSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func videoWriterSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func audioReaderSettings() -> [String : Any]? {
        return nil
    }
    
        // VideoWriter is passthough
    func audioWriterSettings() -> [String : Any]? {
        return nil
    }
    
    func createAssetWriter() {
        guard let writer = try? AVAssetWriter(outputURL: generatedMovieURL, fileType: AVFileType.mov) else {
            failed()
            return
        }
        
        self.assetWriter = writer
    }
    
    func startAssetWriter() {
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    func writeVideoAndAudio() {
        self.writeVideoOnQueue(self.videoQueue)
        self.writeAudioOnQueue(self.audioQueue)
    }
    
    func completed() {
        if self.isCancelled {
            completionAction(nil, "Cancelled")
        }
        else {
            self.completionAction(self.generatedMovieURL, nil)
        }
        
#if os(iOS)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        UNUserNotificationCenter.sendNotification(title: "Completed", body: backgroundDescription + " completed.", soundName: kTimeWarpEditorSuccessSoundName, when: 0.1, repeats:false)
        
        print("\(self.backgroundDescription) Completed")
        
        UIApplication.shared.endBackgroundTask(self.backgroundID)
        self.backgroundID = UIBackgroundTaskIdentifier.invalid
#endif // #if os(iOS)   
    }
    
    func failed() {
        
        var errorMessage:String?
        
        if let error = assetWriter?.error {
            print("failed \(error)")
            print("Error")
            errorMessage = error.localizedDescription
        }
        
        if self.isCancelled {
            errorMessage = "Cancelled"
        }
        
        completionAction(nil, errorMessage)
        
#if os(iOS)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        UNUserNotificationCenter.sendNotification(title: "Completed", body: backgroundDescription + " completed.", soundName: kTimeWarpEditorSuccessSoundName, when: 0.1, repeats:false)
        
        print("\(self.backgroundDescription) Completed")
        
        UIApplication.shared.endBackgroundTask(self.backgroundID)
        self.backgroundID = UIBackgroundTaskIdentifier.invalid
#endif // #if os(iOS)   
    }
    
    func didCompleteWriting() {
        guard writingVideoFinished && writingAudioFinished else { return }
        assetWriter.finishWriting {
            switch self.assetWriter.status {
                case .failed:
                    self.failed()
                case .completed:
                    self.completed()
                default:
                    self.failed()
            }
            
            return
        }
    }
    
    func finishVideoWriting() {
        if writingVideoFinished == false {
            writingVideoFinished = true
            videoWriterInput.markAsFinished()
        }
        
        didCompleteWriting()
    }
    
    func finishAudioWriting() {
        if writingAudioFinished == false {
            writingAudioFinished = true
            audioWriterInput?.markAsFinished()
        }
        
        didCompleteWriting()
    }
    
    func createVideoWriterInput() {
        
        let outputSettings = videoWriterSettings()
        
        if assetWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) {
            
            let videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
            
            if let transform = videoAsset.assetTrackTransform() {
                videoWriterInput.transform = transform
            }
           
            videoWriterInput.expectsMediaDataInRealTime = true
            
            if assetWriter.canAdd(videoWriterInput) {
                assetWriter.add(videoWriterInput)
                self.videoWriterInput = videoWriterInput
            }
        }
    }
    
    func createAudioWriterInput() {
        
        let outputSettings = audioWriterSettings()
        
        let audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: outputSettings)
        
        audioWriterInput.expectsMediaDataInRealTime = false
        
        if assetWriter.canAdd(audioWriterInput) {
            assetWriter.add(audioWriterInput)
            self.audioWriterInput = audioWriterInput
        }
    }
    
    func prepareForReading() {
                
            // Video Reader
        let (_, videoReader, videoReaderOutput) = videoAsset.videoReader(outputSettings: videoReaderSettings())
        
        if let videoReader = videoReader, let videoReaderOutput = videoReaderOutput, videoReader.canAdd(videoReaderOutput) {
            
            if videoReader.canAdd(videoReaderOutput) {
                videoReader.add(videoReaderOutput)
                
                self.videoReader = videoReader
                self.videoReaderOutput = videoReaderOutput
            }
        }
        
            // Audio Reader
        let (_, audioReader, audioReaderOutput) = videoAsset.audioReader(outputSettings: audioReaderSettings())
        
        if let audioReader = audioReader, let audioReaderOutput = audioReaderOutput, audioReader.canAdd(audioReaderOutput) {
            
            if audioReader.canAdd(audioReaderOutput) {
                audioReader.add(audioReaderOutput)
                
                self.audioReader = audioReader
                self.audioReaderOutput = audioReaderOutput
            }
        }
    }
    
    func prepareForWriting() {
        self.createVideoWriterInput()
        self.createAudioWriterInput()
    }
    
    func writeVideoOnQueue(_ serialQueue:DispatchQueue) {
        
        guard self.videoReader.startReading() else {
            self.finishVideoWriting()
            return
        }
        
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
                    
                    guard self.videoWriterInput.append(sampleBuffer) else {
                        self.videoReader?.cancelReading()
                        self.finishVideoWriting()
                        return
                    }
                    
                    self.currentFrameCount += 1
                    let percent = min(CGFloat(self.currentFrameCount) / CGFloat(self.frameCount), 1.0)
                    self.progressAction(percent, nil)
                    
                }
            }
        }
    }
    
    func writeAudioOnQueue(_ serialQueue:DispatchQueue) {
        
        guard let audioReader = self.audioReader, let audioWriterInput = self.audioWriterInput, let audioReaderOutput = self.audioReaderOutput, audioReader.startReading() else {
            self.finishAudioWriting()
            return
        }
        
        audioWriterInput.requestMediaDataWhenReady(on: serialQueue) {
            
            while audioWriterInput.isReadyForMoreMediaData, self.writingAudioFinished == false {
                
                autoreleasepool { () -> Void in
                    
                    guard self.isCancelled == false else {
                        audioReader.cancelReading()
                        self.finishAudioWriting()
                        return
                    }
                    
                    guard let sampleBuffer = audioReaderOutput.copyNextSampleBuffer() else {
                        self.finishAudioWriting()
                        return
                    }
                    
                    guard audioWriterInput.append(sampleBuffer) else {
                        audioReader.cancelReading()
                        self.finishAudioWriting()
                        return
                    }
                    
                }
            }
        }
    }
}
