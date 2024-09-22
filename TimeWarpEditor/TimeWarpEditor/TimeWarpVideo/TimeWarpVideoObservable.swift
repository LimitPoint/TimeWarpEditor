//
//  TimeWarpVideoObservable.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

enum FPS: Int, CaseIterable, Identifiable {
    case any = 0, twentyFour = 24, thirty = 30, sixty = 60
    var id: Self { self }
}

protocol TimeWarpVideoDelegate: AnyObject {
    func timeWarpVideoCancelled()
    func timeWarpVideoDone()
}

class TimeWarpVideoObservable: ObservableObject, PlotAudioDelegate {
    
    weak var timeWarpVideoDelegate:TimeWarpVideoDelegate?
    
    var videoURL:URL {
        didSet {
            self.deleteTimeWarpedVideoURL()
            let videoAsset = AVAsset(url: videoURL)
            self.videoDuration = videoAsset.duration.seconds
            self.plotAudioObservable.asset = videoAsset
            self.loadProgressImage(videoAsset:videoAsset, percent:0)
        }
    }
    var videoDuration:Double = 0
    @Published var timeWarpedVideoURL:URL?
    var documentsURL:URL
    var timeWarpVideoGenerator:TimeWarpVideoGenerator?
    var videoDocument:VideoDocument?
    
    @Published var progressFrameImage:CGImage?
    @Published var progress:Double = 0
    @Published var progressTitle:String = "Progress"
    @Published var isTimeWarping:Bool = false
    @Published var alertInfo: AlertInfo?
    
    @Published var fps:FPS = .sixty
    
    @Published var validatedComponentFunctions = [ComponentFunction()]
    @Published var isComponentsEditing:Bool = false
    
    @Published var fitPathInView:Bool = false
    var timeWarpingPathViewObservable = TimeWarpingPathViewObservable(indicatorAtZero: true, fitPathInView: false)
    
    @Published var expectedTimeWarpedDuration:String = ""
    
        // Selected components for setting video time
    @Published var selectedComponentFunctions = Set<UUID>()

    var periodicTimeObserver:Any?
    @Published var playingTimeWarped = false
    var timeWarpingLUT:[CGPoint] = []
    var cancelBag = Set<AnyCancellable>()
    
    var errorMesssage:String?
    
    @Published var playerItem:AVPlayerItem
    var player:AVPlayer
    var currentPlayerDuration:Double?
    
    var audioPlayer: AVAudioPlayer? // hold on to it!
    
    @Published var includeAudio = true

    var plotAudioObservable:PlotAudioObservable
    
    init() {
        
        videoURL = kDefaultURL
        
        let videoAsset = AVAsset(url: videoURL)
        videoDuration = videoAsset.duration.seconds
        
        plotAudioObservable = PlotAudioObservable(asset: videoAsset)
        playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(url: videoURL)
        
        documentsURL = FileManager.documentsURL(filename: nil, inSubdirectory: nil)!
        print("path = \(documentsURL.path)")
        
        self.loadProgressImage(videoAsset:videoAsset, percent:0)
        
        timeWarpedVideoURL = urlForTimeWarpedVideoIfItExists()
        
        plotAudioObservable.plotAudioDelegate = self
        
        deleteTimeWarpedVideoURL()
        
        //playOriginal()
                
        $playerItem.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateExpectedTimeWarpedDuration()
            }
            
        }
        .store(in: &cancelBag)
        
        $validatedComponentFunctions.sink { [weak self] newValidatedComponentFunctions in
            self?.timeWarpingPathViewObservable.componentFunctions = newValidatedComponentFunctions
            
            DispatchQueue.main.async {
                self?.updateExpectedTimeWarpedDuration()
            }
        }
        .store(in: &cancelBag)
        
        $fitPathInView.sink { [weak self] newFitPathInView in
            self?.timeWarpingPathViewObservable.fitPathInView = newFitPathInView
        }
        .store(in: &cancelBag)
        
        timeWarpingPathViewObservable.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send() // ensures the plot view text label 'Time Warp on [0,1] to [x,y]' changes
        }.store(in: &cancelBag)
        
        plotAudioObservable.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send() 
        }.store(in: &cancelBag)
        
        $selectedComponentFunctions.sink { [weak self] newSelectedComponentFunctions in
            if newSelectedComponentFunctions != self?.selectedComponentFunctions, let selectedComponentFunctions = self?.selectedComponentFunctions {
                if let newItemID = newSelectedComponentFunctions.subtracting(selectedComponentFunctions).first {
                    self?.playVideoForSelectedComponentFunctionID(newItemID)
                }
            }
        }.store(in: &cancelBag)

        self.timeWarpingPathViewObservable.componentPathSelectionHandler = componentPathSelectionHandler(_:)
    }
    
    func loadProgressImage(videoAsset:AVAsset, percent:Float) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else {
                return
            }
            let frame = videoAsset.getCGImageAssetFrame(CMTime.zero, percent: percent)
            DispatchQueue.main.async {
                self.progressFrameImage = frame
            }
        }
    }
    
    func componentPathSelectionHandler(_ selections:Set<UUID>) {
        selectedComponentFunctions = selections
    }
    
    func tryDownloadingUbiquitousItem(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        var downloadedURL:URL?
        
        if FileManager.default.isUbiquitousItem(at: url) {
            
            let queue = DispatchQueue(label: "com.limit-point.startDownloadingUbiquitousItem")
            let group = DispatchGroup()
            group.enter()
            
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now()) { [weak self] in
                
                do {
                    try FileManager.default.startDownloadingUbiquitousItem(at: url)
                    let error:NSErrorPointer = nil
                    let coordinator = NSFileCoordinator(filePresenter: nil)
                    coordinator.coordinate(readingItemAt: url, options: NSFileCoordinator.ReadingOptions.withoutChanges, error: error) { readURL in
                        downloadedURL = readURL
                    }
                    if let error = error {
                        self?.errorMesssage = error.pointee?.localizedFailureReason
                        print("Can't download the URL: \(self?.errorMesssage ?? "No avaialable error from NSFileCoordinator")")
                    }
                    group.leave()
                }
                catch {
                    self?.errorMesssage = error.localizedDescription
                    print("Can't download the URL: \(error.localizedDescription)")
                    group.leave()
                }
            }
            
            group.notify(queue: queue, execute: {
                completion(downloadedURL)
            })
        }
        else {
            self.errorMesssage = "URL is not ubiquitous item"
            completion(nil)
        }
    }
    
    func copyURL(_ url: URL, completion: @escaping (URL?) -> ()) {
        
        //let filename = url.lastPathComponent
        let filename = timeWarpFilename_copied
        
        if let copiedURL = FileManager.documentsURL(filename: "\(filename)", inSubdirectory: timeWarpSubdirectoryName) {
            
            try? FileManager.default.removeItem(at: copiedURL)
            
            do {
                try FileManager.default.copyItem(at: url, to: copiedURL)
                completion(copiedURL)
            }
            catch {
                tryDownloadingUbiquitousItem(url) { downloadedURL in
                    
                    if let downloadedURL = downloadedURL {
                        do {
                            try FileManager.default.copyItem(at: downloadedURL, to: copiedURL)
                            completion(copiedURL)
                        }
                        catch {
                            self.errorMesssage = error.localizedDescription
                            completion(nil)
                        }
                    }
                    else {
                        self.errorMesssage = error.localizedDescription
                        completion(nil)
                    }
                }
            }
        }
        else {
            completion(nil)
        }
    }
    
    func loadAndPlayURL(_ url:URL) {
        self.videoURL = url
        self.play(url)
    }
    
    func loadSelectedURL(_ url:URL, completion: @escaping (Bool) -> ()) {
        
        let scoped = url.startAccessingSecurityScopedResource()
        
        copyURL(url) { copiedURL in
            
            if scoped { 
                url.stopAccessingSecurityScopedResource() 
            }
            
            DispatchQueue.main.async { [weak self] in
                
                guard let self = self else {
                    completion(false)
                    return
                }
                
                if let copiedURL = copiedURL {
                    self.loadAndPlayURL(copiedURL)
                    completion(true)
                }
                else {
                    completion(false)
                }
            }
        }
    }
    
    func playVideoForSelectedComponentFunctionID(_ id:UUID) {
        if let index = validatedComponentFunctions.firstIndex(where: {$0.id == id}) {
            let selectedComponentFunction = validatedComponentFunctions[index]
            
            let unitTime = selectedComponentFunction.range.lowerBound
            var startTime = unitTime * videoDuration
            if playingTimeWarped {
                startTime = integrator(unitTime) * videoDuration
            }
            
            player.seek(to: CMTimeMakeWithSeconds(startTime, preferredTimescale: kTimeScaleForSeconds), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
            player.play()
        }
    }
    
    func indicatorTime(currentPlayerTime: Double) -> Double {
        var currentTime:Double = 0
        
        if playingTimeWarped {
            if let lut = lookupTime(currentPlayerTime) {
                currentTime = lut
            }
        }
        else {
            currentTime = currentPlayerTime / self.videoDuration
        }
        
        return currentTime
    }
    
    func play(_ url:URL) {
        
        playingTimeWarped = ( url == timeWarpedVideoURL ? true : false)
        
        if let periodicTimeObserver = periodicTimeObserver {
            self.player.removeTimeObserver(periodicTimeObserver)
        }
        
        self.player.pause()
        playerItem = AVPlayerItem(url: url)
        self.player.replaceCurrentItem(with: playerItem)
        
        let asset = AVAsset(url: url)
        self.plotAudioObservable.asset = asset
        let duration = asset.duration.seconds
        self.currentPlayerDuration = duration
        periodicTimeObserver = self.player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
            
            if let indicatorTime = self?.indicatorTime(currentPlayerTime:cmTime.seconds) {
                self?.timeWarpingPathViewObservable.indicatorTime = indicatorTime
                self?.plotAudioObservable.indicatorPercent = cmTime.seconds / duration
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .milliseconds(500)) { [weak self] in
            self?.player.play()
        }
        
    }
    
    func playOriginal() {
        play(videoURL)
    }
    
    func playTimeWarped() {
        guard let url = self.timeWarpedVideoURL else {
            self.alertInfo = AlertInfo(id: .noTimeWarpedVideoURL, title: "No Time Warped Video", message: "Time warp a video and try again.")
            return
        }
        play(url)
    }
    
    func integrator(_ t:Double) -> Double {
        return integrateComponents(t, components: self.validatedComponentFunctions) ?? 1
    }
    
    func printDurations(_ resultURL:URL) {
        let assetresult = AVAsset(url: resultURL)
        
        let scale = integrator(1)
        
        if let videoTrack = assetresult.tracks(withMediaType: .video).first {
            let videoTrackDuration = videoTrack.timeRange.duration.seconds
            print("time warped video duration = \(videoTrackDuration)")
        }
        
        if let audioTrack = assetresult.tracks(withMediaType: .audio).first {
            let audioTrackDuration = audioTrack.timeRange.duration.seconds
            print("time warped audio duration = \(audioTrackDuration)")
        }
        
        let assetinput = AVAsset(url: self.videoURL)
        
        if let videoTrack = assetinput.tracks(withMediaType: .video).first {
            let videoTrackDuration = videoTrack.timeRange.duration.seconds
            print("original video duration = \(videoTrackDuration)")
            print("original video duration * scale = \(videoTrackDuration * scale)")
        }
        
        if let audioTrack = assetinput.tracks(withMediaType: .audio).first {
            let audioTrackDuration = audioTrack.timeRange.duration.seconds
            print("original audio duration  = \(audioTrackDuration)")
            print("original audio duration * scale  = \(audioTrackDuration * scale)")
        }
    }
    
    func timeWarpedVideoPath() -> String {
        let filename = timeWarpFilename_timewarped
        return FileManager.documentsURL(filename: "\(filename)", inSubdirectory: timeWarpSubdirectoryName)!.path 
    }
    
    func urlForTimeWarpedVideoIfItExists() -> URL? {
        let path = timeWarpedVideoPath()
        if FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
    
    func deleteTimeWarpedVideoURL() {
        if let url = urlForTimeWarpedVideoIfItExists() {
            try? FileManager.default.removeItem(at: url)
        }
        timeWarpedVideoURL = nil
    }
    
    func warp() {
        
        self.player.pause()
        
        isTimeWarping = true
        timeWarpingLUT.removeAll()
                    
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            var lastDate = Date()
            var updateProgressImage = true
            var totalElapsed:TimeInterval = 0
            
            guard let path = self?.videoURL.path, let fps = self?.fps.rawValue, let includeAudio = self?.includeAudio, let destinationPath = self?.timeWarpedVideoPath(), let integrator = self?.integrator else {
                DispatchQueue.main.async {
                    self?.alertInfo = AlertInfo(id: .timeWarpingFailed, title: "Time Warping Failef", message: "Process could not initialize.")
                }
                return
            }
            
            self?.timeWarpVideoGenerator = TimeWarpVideoGenerator(path: path, frameRate: Int32(fps), includeAudio: includeAudio, destination: destinationPath, integrator: integrator, progress: { (value, ciimage) in
                
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
                        
                        self?.printDurations(resultURL)
                        
                        self?.playTimeWarped()
                    }
                    else {
                        if self?.timeWarpVideoGenerator?.isCancelled == true {
                            self?.alertInfo = AlertInfo(id: .timeWarpingFailed, title: "Time Warping Cancelled", message: "The operation was cancelled.")
                        }
                        else if self?.timeWarpVideoGenerator?.outOfOrder == true {
                            self?.alertInfo = AlertInfo(id: .timeWarpingFailed, title: "Time Warping Failed", message: "Time Warping produced out of order presentation times.\n\nTry different settings for factor, modifer or frame rate.")
                        }
                        else {
                            var message = (errorMessage ?? "Error message not available")
                            message += "\n\nTry different settings for factor, modifer or frame rate."
                            self?.alertInfo = AlertInfo(id: .timeWarpingFailed, title: "Time Warping Failed", message: message)
                        }
                        
                        self?.errorSound()  // if success the time warped video plays
                    }
                    
                    self?.timeWarpVideoGenerator = nil
                }
            })
            
            self?.timeWarpVideoGenerator?.start()
        }
    }
    
    func cancel() {
        self.timeWarpVideoGenerator?.isCancelled = true
    }
    
    func saveLastImportedFilename(_ importedURL:URL?) {
        if let importedURL = importedURL {
            UserDefaults.standard.set(importedURL.deletingPathExtension().lastPathComponent, forKey: kTimeWarpLastImportedFilenameKey)
        }
    }
    
    func lastImportedFilename() -> String? {
        return UserDefaults.standard.string(forKey: kTimeWarpLastImportedFilenameKey)
    }
    
    func prepareToExportTimeWarpedVideo() -> Bool {
        guard let url = self.timeWarpedVideoURL else {
            self.alertInfo = AlertInfo(id: .noTimeWarpedVideoURL, title: "No Time Warped Video", message: "Time warp a video and try again.")
            return false
        }
        self.player.pause() // export alert can't be dismissed while video is playing.
        videoDocument = VideoDocument(url: url)
        return true
    }
    
    func secondsToString(secondsIn:Double) -> String {
        
        if CGFloat(secondsIn) > (CGFloat.greatestFiniteMagnitude / 2.0) {
            return "∞"
        }
        
        let secondsRounded = round(secondsIn)
        
        let hours:Int = Int(secondsRounded / 3600)
        
        let minutes:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds:Int = Int(secondsRounded.truncatingRemainder(dividingBy: 60))
        
        
        if hours > 0 {
            return String(format: "%i:%02i:%02i", hours, minutes, seconds)
        } else {
            return String(format: "%02i:%02i", minutes, seconds)
        }
    }
    
    func updateExpectedTimeWarpedDuration() {
        
        let videoAsset = AVAsset(url: videoURL)
        let assetDurationSeconds = videoAsset.duration.seconds
        
        let scaleFactor = integrator(1)
        
        let timeWarpedDuration = scaleFactor * assetDurationSeconds
        
        expectedTimeWarpedDuration = secondsToString(secondsIn: timeWarpedDuration)
        
        let estimatedFrameCount = videoAsset.estimatedFrameCount()
        let estimatedFrameRate = Double(estimatedFrameCount) / timeWarpedDuration
        
        expectedTimeWarpedDuration += " (\(String(format: "%.2f", estimatedFrameRate)) FPS)"
    }
    
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
    
    // PlotAudioDelegate
    func plotAudioDragChanged(_ value: CGFloat) {
        player.pause()
        player.seek(to: CMTimeMakeWithSeconds(value * videoDuration, preferredTimescale: kPreferredTimeScale), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    
    // PlotAudioDelegate
    func plotAudioDragEnded(_ value: CGFloat) {
        player.play()
    }
    
    // PlotAudioDelegate
    func plotAudioDidFinishPlotting() {
        
    }
}
