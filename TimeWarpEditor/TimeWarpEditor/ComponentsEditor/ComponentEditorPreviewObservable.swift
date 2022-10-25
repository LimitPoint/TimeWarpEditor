//
//  ComponentEditorPreviewObservable.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 8/20/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine
 
class ComponentEditorPreviewObservable: ObservableObject {
    
    var componentEditorObservable:ComponentEditorObservable
    
    var videoRangeClip:AVAsset   // video clip to warp
    var componentFunction:ComponentFunction

    var timeWarpVideoGenerator:TimeWarpVideoGenerator?
    var timeWarpedVideoURL:URL?
    @Published var errorMessage:String? = nil
    
    @Published var progressFrameImage:CGImage?
    @Published var progress:Double = 0
    @Published var progressTitle:String = "Progress"
    @Published var isTimeWarping:Bool = true
    
    @Published var warpedVideoPlayer:AVPlayer
    @Published var videoRangeClipPlayer:AVPlayer
    
    @Published var fitPathInView:Bool = false
    var timeWarpingPathViewObservable = TimeWarpingPathViewObservable(indicatorAtZero: true, fitPathInView: false)
    
    var expectedTimeWarpedDuration:String = ""
    
    var periodicTimeObserver:Any?
    var timeWarpingLUT:[CGPoint] = []
    
    var cancelBag = Set<AnyCancellable>()
    
    var audioPlayer: AVAudioPlayer?
    
    init(componentEditorObservable:ComponentEditorObservable) {
        
        self.componentEditorObservable = componentEditorObservable
        
        self.componentFunction = componentEditorObservable.component
        
        self.componentFunction.range = 0.0...1.0 // adjust the range to the full range so as to cover the whole video clip
        
        let avAsset = componentEditorObservable.videoClipForRange()
        self.videoRangeClip = avAsset
        
        let warpedVideoPlayerItem = AVPlayerItem(asset: avAsset)
        warpedVideoPlayer = AVPlayer(playerItem: warpedVideoPlayerItem)
        
        let videoRangeClipPlayerItem = AVPlayerItem(asset: avAsset)
        videoRangeClipPlayer = AVPlayer(playerItem: videoRangeClipPlayerItem)
        
        progressFrameImage = avAsset.getCGImageAssetFrame(CMTime.zero, percent: 0)
        
        timeWarpingPathViewObservable.componentFunctions = [self.componentFunction]
        
        updateExpectedTimeWarpedDuration()
        
        $fitPathInView.sink { [weak self] newFitPathInView in
            self?.timeWarpingPathViewObservable.fitPathInView = newFitPathInView
        }
        .store(in: &cancelBag)

    }
    
    deinit {
        print("ComponentEditorPreviewObservable deinit")
    }
    
    func cancel() {
        self.timeWarpVideoGenerator?.isCancelled = true
        
        warpedVideoPlayer.pause()
        videoRangeClipPlayer.pause()
        componentEditorObservable.stopPreviewing()
    }
    
    func integrator(_ t:Double) -> Double {
        return integrateComponents(t, components: [self.componentFunction]) ?? 1
    }
    
    func updateExpectedTimeWarpedDuration() {
        
        let assetDurationSeconds = self.videoRangeClip.duration.seconds
        
        let scaleFactor = integrator(1)
        
        let timeWarpedDuration = scaleFactor * assetDurationSeconds
        
        expectedTimeWarpedDuration = secondsToString(secondsIn: timeWarpedDuration)
        
        let estimatedFrameCount = self.videoRangeClip.estimatedFrameCount()
        let estimatedFrameRate = Double(estimatedFrameCount) / timeWarpedDuration
        
        expectedTimeWarpedDuration += " (\(String(format: "%.2f", estimatedFrameRate)) FPS)"
    }
    
        // Borrowed TimeWarpVideoObservable
    func lookupTime(_ time:Double) -> Double? {
        
        guard timeWarpingLUT.count > 0 else {
            return nil
        }
        
        var value:Double?
        
        let lastTime = timeWarpingLUT[timeWarpingLUT.count-1].y
        
            // find range of scaled time in timeWarpingLUT, return interpolated value
        for i in 0...timeWarpingLUT.count-2 {
            if timeWarpingLUT[i].x <= time && timeWarpingLUT[i+1].x >= time {
                
                let d = timeWarpingLUT[i+1].x - timeWarpingLUT[i].x
                
                if d > 0 {
                    value = ((timeWarpingLUT[i].y + (time - timeWarpingLUT[i].x) * (timeWarpingLUT[i+1].y - timeWarpingLUT[i].y) / d)) / lastTime
                }
                else {
                    value = timeWarpingLUT[i].y / lastTime
                }
                
                break
            }
        }
        
            // time may overflow end of table, use 1
        if value == nil {
            value = 1
        }
        
        return value
    }
    
    // Similar to 'warp()' of TimeWarpVideoObservable
    func warpPreview() {
        
        timeWarpingLUT.removeAll()
                
        let destinationPath = FileManager.documentsURL(filename: timeWarpFilename_preview, inSubdirectory: timeWarpSubdirectoryName)!.path 
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        
            var lastDate = Date()
            var updateProgressImage = true
            var totalElapsed:TimeInterval = 0
            
            guard let integrator = self?.integrator, let videoRangeClip = self?.videoRangeClip else {
                DispatchQueue.main.async {
                    self?.isTimeWarping = false
                    self?.errorMessage = "Warping can't start."
                }
                return
            }
            
            self?.timeWarpVideoGenerator = TimeWarpVideoGenerator(asset: videoRangeClip, frameRate: 30, destination: destinationPath, integrator: integrator, progress: { (value, ciimage) in
                
                DispatchQueue.main.async {
                    self?.progress = value
                    self?.progressTitle = "Progress \(String(format: "%.2f", value * 100))%"
                }
                
                let elapsed = Date().timeIntervalSince(lastDate)
                lastDate = Date()
                
                totalElapsed += elapsed
                
                if totalElapsed > 0.3 && updateProgressImage {
                    
                    updateProgressImage = false
                    
                    totalElapsed = 0
                    
                    var previewImage:CGImage?
                    
                    autoreleasepool {
                        if let image = ciimage {
                            previewImage = image.cgimage()
                        }
                    }
                    
                    DispatchQueue.main.async {
                        autoreleasepool {
                            if let previewImage = previewImage {
                                self?.progressFrameImage = previewImage
                            }
                        }
                        
                        updateProgressImage = true
                    }
                }
                
            }, completion: { (resultURL, errorMessage) in
                
                DispatchQueue.main.async {
                    
                    self?.progress = 0
                    self?.isTimeWarping = false
                    
                    if let resultURL = resultURL, self?.timeWarpVideoGenerator?.isCancelled == false, self?.timeWarpVideoGenerator?.outOfOrder == false {
                        self?.timeWarpedVideoURL = resultURL
                        
                        if let timeWarpingLUT = self?.timeWarpVideoGenerator?.timeWarpingLUT {
                            self?.timeWarpingLUT.append(contentsOf: timeWarpingLUT)
                        }
                        
                        self?.playTimeWarped()
                    }
                    else {
                        if self?.timeWarpVideoGenerator?.isCancelled == true {
                            self?.errorMessage = "Time Warping Cancelled"
                        }
                        else if self?.timeWarpVideoGenerator?.outOfOrder == true {
                            self?.errorMessage = "Time Warping Failed"
                        }
                        else {
                            var message = (errorMessage ?? "Error message not available")
                            message += "\n\nTry different settings for factor, modifer or frame rate."
                            self?.errorMessage = message
                        }
                        
                        self?.errorSound()  // if success the time warped video plays
                    }
                    
                    self?.timeWarpVideoGenerator = nil
                }
        
            })
            
            self?.timeWarpVideoGenerator?.start()
        }
    }
    
        // Borrowed TimeWarpVideoObservable
    func indicatorTime(currentPlayerTime: Double) -> Double {
        var currentTime:Double = 0
        
        if let lut = lookupTime(currentPlayerTime) {
            currentTime = lut
        }
        
        return currentTime
    }
    
        // Borrowed TimeWarpVideoObservable's play(_ url:URL)
    func playTimeWarped() {
        guard let url = self.timeWarpedVideoURL else {
            self.errorMessage = "No Time Warped Video"
            return
        }
        
        if let periodicTimeObserver = periodicTimeObserver {
            self.warpedVideoPlayer.removeTimeObserver(periodicTimeObserver)
        }
        
        self.warpedVideoPlayer.pause()
        self.warpedVideoPlayer = AVPlayer(url: url)
        
        periodicTimeObserver = self.warpedVideoPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
            
            if let indicatorTime = self?.indicatorTime(currentPlayerTime:cmTime.seconds) {
                self?.timeWarpingPathViewObservable.indicatorTime = indicatorTime
            }
        }
                
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) { [weak self] in
            self?.warpedVideoPlayer.play()
        }
    }
    
    // play sounds
    func errorSound() {
        if let url = Bundle.main.url(forResource: "Echo", withExtension: "m4a") {
            playAudioURL(url)
        }
    }
    
    func playAudioURL(_ url:URL) {
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)         
            
            if let audioPlayer = audioPlayer {
                audioPlayer.prepareToPlay()
                audioPlayer.play()
            }
            
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func videoClipIsLandscape() -> Bool {
        var isLandscape = true
        
        if let cgImage = progressFrameImage {
            if cgImage.width <= cgImage.height {
                isLandscape = false
            }
        }
        
        return isLandscape
    }
}
