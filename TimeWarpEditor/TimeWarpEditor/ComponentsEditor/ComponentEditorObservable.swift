//
//  ComponentEditorObservable.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 7/9/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

/*
 Note:
 
 This class is intended to be used in conjunction with startEditing and endEditing of ComponentsEditorObservable
 
 */
class ComponentEditorObservable: ObservableObject, PlotAudioDelegate, RangedSliderViewDelegate {

    var componentsEditorObservable:ComponentsEditorObservable

        // Component editor view
    var leftPlayer:AVPlayer
    var leftPlayerPeriodicTimeObserver:Any?
    var leftPlayerItem:AVPlayerItem
    var rightPlayer:AVPlayer
    var rightPlayerPeriodicTimeObserver:Any?
    var rightPlayerItem:AVPlayerItem
    
    @Published var videoRangeClipPlayer:AVPlayer
    
    @Published var range:ClosedRange<Double> = 0...1 // unit interval time range
    @Published var frameCountRange:ClosedRange<Double> // frame count range for time range - better for the range slider class
    
        // Component Editor properties
    @Published var selectedTimeWarpFunctionType:TimeWarpFunctionType = .doubleSmoothstep
    @Published var isFlipped = false
    
    @Published var factor:Double = 1.5 // 0.1 to 2
    @Published var modifier:Double = 0.5 // 0.1 to 1
    
        // Component Editor time warping path
    @Published var fitPathInView:Bool = false
    var timeWarpingPathViewObservable = TimeWarpingPathViewObservable(indicatorAtZero: false, fitPathInView: false)
    
    @Published var frameIncrementValue:Int = 1
    var frameDuration:Double
    
    // Preview component
    @Published var isPreviewing:Bool = false
    var componentEditorPreviewObservable:ComponentEditorPreviewObservable?
    
    var plotAudioObservable:PlotAudioObservable
    
    var cancelBag = Set<AnyCancellable>()
    
    var component:ComponentFunction {
        return ComponentFunction(range: range, factor: factor, modifier: modifier, timeWarpFunctionType: timeWarpFunctionType())!
    }
    
    init(componentsEditorObservable:ComponentsEditorObservable) {
        
        self.componentsEditorObservable = componentsEditorObservable
        
        leftPlayer = AVPlayer(url: componentsEditorObservable.videoURL)
        leftPlayerItem = leftPlayer.currentItem! // used in seek
        
        rightPlayer = AVPlayer(url: componentsEditorObservable.videoURL)
        rightPlayerItem = rightPlayer.currentItem! // used in seek
        
        videoRangeClipPlayer = AVPlayer(url: componentsEditorObservable.videoURL)
        
        // Players and ranges syncing
        frameCountRange = 1.0...componentsEditorObservable.videoFrameCount
        
        frameDuration = componentsEditorObservable.videoDuration / componentsEditorObservable.videoFrameCount
        
        plotAudioObservable = PlotAudioObservable(url: componentsEditorObservable.videoURL)
        plotAudioObservable.plotAudioDelegate = self
        
        syncPlayerTimesToRange()  
        syncPlotAudioSelectionToRange()
        
        // Periodic time observors for the audio plot
        leftPlayerPeriodicTimeObserver = self.leftPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
            self?.plotAudioObservable.indicatorPercent = cmTime.seconds / componentsEditorObservable.videoDuration
        }
        
        rightPlayerPeriodicTimeObserver = self.rightPlayer.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 30), queue: nil) { [weak self] cmTime in
            self?.plotAudioObservable.indicatorPercent = cmTime.seconds / componentsEditorObservable.videoDuration
        }
        
        updatePath()
        
        $range.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.syncPlayerTimesToRange()
                self?.syncPlotAudioSelectionToRange()
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $frameCountRange.sink { [weak self]  newValue in
            self?.range = rangeForFrameCountRange(frameCountRange: newValue, videoFrameCount: componentsEditorObservable.videoFrameCount)
        }
        .store(in: &cancelBag)
        
        $factor.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $modifier.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $selectedTimeWarpFunctionType.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $isFlipped.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
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
    }
    
    deinit {
        print("ComponentEditorObservable deinited")
        
        if let leftPlayerPeriodicTimeObserver = leftPlayerPeriodicTimeObserver {
            self.leftPlayer.removeTimeObserver(leftPlayerPeriodicTimeObserver)
        }
        
        if let rightPlayerPeriodicTimeObserver = rightPlayerPeriodicTimeObserver {
            self.rightPlayer.removeTimeObserver(rightPlayerPeriodicTimeObserver)
        }
    }
    
    func updateVideoRangeClip() {
        let videoRangeClip = self.videoClipForRange()
        let videoRangeClipPlayerItem = AVPlayerItem(asset: videoRangeClip)
        self.videoRangeClipPlayer.replaceCurrentItem(with: videoRangeClipPlayerItem)
    }
    
    func rangedSliderEnded() {
        updateVideoRangeClip()
    }
    
    func frameIncrementSeconds() -> Double {
        Double(frameIncrementValue) * frameDuration
    }
    
        // Map value in [0,1] to CMTime in video
    func cmTimeForUnitIntervalValue(_ unitValue:Double) -> CMTime {
        CMTimeMakeWithSeconds(unitValue * componentsEditorObservable.videoDuration, preferredTimescale: kTimeScaleForSeconds)
    }
    
        // Map CMTime in video to value in [0,1]
    func unitIntervalValueForCMTime(_ cmTime:CMTime) -> Double {
        CMTimeGetSeconds(cmTime) / componentsEditorObservable.videoDuration
    }
    
    func syncPlayerTimesToRange() {
        leftPlayer.pause()
        leftPlayerItem.seek(to: cmTimeForUnitIntervalValue(range.lowerBound), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: nil)
        
        rightPlayer.pause()
        rightPlayerItem.seek(to: cmTimeForUnitIntervalValue(range.upperBound), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero, completionHandler: nil)
    }
    
    func syncPlotAudioSelectionToRange() {
        plotAudioObservable.selectionRange = range
    }
    
    func timeWarpFunctionType() -> TimeWarpFunctionType {
        if selectedTimeWarpFunctionType.flippedType() == nil {
            return selectedTimeWarpFunctionType
        }
        
        if isFlipped {
            return selectedTimeWarpFunctionType.flippedType()!
        }
        
        return selectedTimeWarpFunctionType
    }
    
    func updatePath() {
        if let component = ComponentFunction(range: range, factor: factor, modifier: modifier, timeWarpFunctionType: timeWarpFunctionType()), let validatedComponentFunctions = addConstantCompliments([component]) {
            self.timeWarpingPathViewObservable.componentFunctions = validatedComponentFunctions
        }
    }
    
    func componentEditorFrameRangeIsValid() -> Bool {
        
        if let index = componentsEditorObservable.componentFunctions.firstIndex(where: {$0.id == componentsEditorObservable.editingID}) {
            
            var ranges = componentsEditorObservable.componentFunctionRanges()
            
            ranges.remove(at: index)
            ranges.append(rangeForFrameCountRange(frameCountRange: self.frameCountRange, videoFrameCount: componentsEditorObservable.videoFrameCount))
            
            return rangesOverlap(ranges) == false
        }
        
        return true
    }
    
    func componentEditorFrameRanges() -> [ClosedRange<Double>] {
        var allRanges = componentsEditorObservable.componentFunctions.map({ cf in
            cf.range
        })
        
        if let index = componentsEditorObservable.componentFunctions.firstIndex(where: {$0.id == componentsEditorObservable.editingID}) {
            allRanges.remove(at: index)
        }
        
        return allRanges
    }
    
    func matchFitRangetoAvailableRanges() {
        let range = rangeForFrameCountRange(frameCountRange: frameCountRange, videoFrameCount: componentsEditorObservable.videoFrameCount)
        if let fittingRange = matchFitRangetoComplimentOfRanges(range: range, ranges: componentEditorFrameRanges()) {
            frameCountRange = frameCountRangeForRange(range: fittingRange, videoFrameCount: componentsEditorObservable.videoFrameCount)
        }
    }
    
    // Stepper buttons for range fine tune
    func canIncrementRangeLeft() -> Bool {
        return frameCountRange.lowerBound+Double(frameIncrementValue) < frameCountRange.upperBound
    }
    func incrementRangeLeft() {
        if canIncrementRangeLeft() {
            frameCountRange = frameCountRange.lowerBound+Double(frameIncrementValue)...frameCountRange.upperBound
            
            updateVideoRangeClip()
        }
    }
    
    func canDecrementRangeLeft() -> Bool {
        return frameCountRange.lowerBound-Double(frameIncrementValue) >= 1
    }
    func decrementRangeLeft() {
        if canDecrementRangeLeft() {
            frameCountRange = frameCountRange.lowerBound-Double(frameIncrementValue)...frameCountRange.upperBound
            
            updateVideoRangeClip()
        }
    }
    
    func canIncrementRangeRight() -> Bool {
        return frameCountRange.upperBound+Double(frameIncrementValue) <= componentsEditorObservable.videoFrameCount
    }
    func incrementRangeRight() {
        if canIncrementRangeRight() {
            frameCountRange = frameCountRange.lowerBound...frameCountRange.upperBound+Double(frameIncrementValue)
            
            updateVideoRangeClip()
        }
    }
    
    func canDecrementRangeRight() -> Bool {
        return frameCountRange.upperBound-Double(frameIncrementValue) > frameCountRange.lowerBound
    }
    func decrementRangeRight() {
        if canDecrementRangeRight() {
            frameCountRange = frameCountRange.lowerBound...frameCountRange.upperBound-Double(frameIncrementValue)
            
            updateVideoRangeClip()
        }
    }
    
    func videoClipForRange() -> AVAsset {
        let videoAsset = AVAsset(url: componentsEditorObservable.videoURL)
        
        return videoAsset.trimComposition(from: cmTimeForUnitIntervalValue(range.lowerBound), to: cmTimeForUnitIntervalValue(range.upperBound)) ?? AVAsset(url: kDefaultURL)
    }
    
    // PlotAudioDelegate
    func plotAudioDragChanged(_ value: CGFloat) {
        leftPlayer.pause()
        rightPlayer.pause()
        leftPlayer.seek(to: CMTimeMakeWithSeconds(value * componentsEditorObservable.videoDuration, preferredTimescale: kPreferredTimeScale), toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    
        // PlotAudioDelegate
    func plotAudioDragEnded(_ value: CGFloat) {
        leftPlayer.play()
    }
    
        // PlotAudioDelegate
    func plotAudioDidFinishPlotting() {
        
    }
    
    func startPreviewing() {
        leftPlayer.pause()
        rightPlayer.pause()
        componentEditorPreviewObservable = ComponentEditorPreviewObservable(componentEditorObservable: self)
        isPreviewing = true
    }
    
    func stopPreviewing() {
        isPreviewing = false
        componentEditorPreviewObservable = nil
    }
}
