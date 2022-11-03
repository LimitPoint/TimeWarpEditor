//
//  ComponentsEditorObservable.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/25/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import Foundation
import SwiftUI
import AVFoundation
import Combine

let kDefaultVideoURL = Bundle.main.url(forResource: "DefaultVideo", withExtension: "mov")!
let kTimeScaleForSeconds:Int32 = 64000
let kRangePrecisonDisplay = "%.3f" // Used in RangedSliderView, ComponentRangeView

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

class ComponentsEditorObservable: ObservableObject {
    
    @Published var componentFunctions:[ComponentFunction] 
    @Published var validatedComponentFunctions:[ComponentFunction]? // validated, completed and sorted components if possible
    
    // Selected table rows - for deleting
    @Published var selectedComponentFunctions = Set<UUID>()
    @Published var isEditing:Bool = false
    var editingID:UUID? = nil
    
    @Published var scrollToID:UUID?
    
    var videoURL:URL {
        didSet {
            setVideoParameters()
        }
    }
    
    var videoDuration:Double!
    var videoFrameRate:Double!
    var videoFrameCount:Double!
    var videoAsset:AVAsset!
    
    var cancelBag = Set<AnyCancellable>()
    
    var componentEditorObservable:ComponentEditorObservable?
    @Published var fitPathInView:Bool = false
    var timeWarpingPathViewObservable = TimeWarpingPathViewObservable(indicatorAtZero: false, fitPathInView: false)
    
    init(videoURL:URL = kDefaultVideoURL, componentFunctions:[ComponentFunction]) {
        
        self.videoURL = videoURL
        self.componentFunctions = componentFunctions
        self.validatedComponentFunctions = addConstantCompliments(componentFunctions)
        
        setVideoParameters()
        
        $validatedComponentFunctions.sink { [weak self] _ in
            DispatchQueue.main.async {
                if let validatedComponentFunctions = self?.validatedComponentFunctions {
                    self?.timeWarpingPathViewObservable.componentFunctions = validatedComponentFunctions
                }
            }
        }
        .store(in: &cancelBag)
        
        $componentFunctions.sink { [weak self] newComponentFunctions in
            self?.validatedComponentFunctions = addConstantCompliments(newComponentFunctions)
        }
        .store(in: &cancelBag)
        
        $fitPathInView.sink { [weak self] newFitPathInView in
            self?.timeWarpingPathViewObservable.fitPathInView = newFitPathInView
        }
        .store(in: &cancelBag)
        
        timeWarpingPathViewObservable.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send() // ensures the plot view text label 'Time Warp on [0,1] to [x,y]' changes
        }.store(in: &cancelBag)
        
        $selectedComponentFunctions.sink { [weak self] newSelectedComponentFunctions in
            if newSelectedComponentFunctions != self?.selectedComponentFunctions, let selectedComponentFunctions = self?.selectedComponentFunctions {
                
                if let newItemID = newSelectedComponentFunctions.subtracting(selectedComponentFunctions).first {
                    self?.scrollToID = newItemID
                    print("set scroll to line = \(newItemID)")
                }
                self?.timeWarpingPathViewObservable.selectedComponentFunctions = newSelectedComponentFunctions
            }
            
        }.store(in: &cancelBag)
        
        self.timeWarpingPathViewObservable.componentPathSelectionHandler = componentPathSelectionHandler(_:)

    }
    
    func componentPathSelectionHandler(_ selections:Set<UUID>) {
        selectedComponentFunctions = selections
    }
    
    func setVideoParameters() {
        videoAsset = AVAsset(url: videoURL)
        videoDuration = videoAsset.duration.seconds
        
        videoFrameRate = 30
        if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
            videoFrameRate = max(Double(videoTrack.nominalFrameRate), 1.0)
        }
        
        videoFrameCount = Double(Int(videoFrameRate * videoDuration)) // for consistency with RangedSliderView that uses Int values
    }
    
    func validatedComponents() -> [ComponentFunction] {
        var components = [ComponentFunction()]
        if let validatedComponentFunctions = validatedComponentFunctions {
            components = validatedComponentFunctions
        }
        return components
        
    }
    
    func sortComponentFunctions() {
        if let sortedComponentFunctions = sortComponentFuntions(componentFunctions) {
            componentFunctions = sortedComponentFunctions
        }
    }
     
    func addComponent() {
        if let firstRange = firstAvailableRangeForComponentFunction() {
            componentFunctions.append(ComponentFunction(range: firstRange))
            sortComponentFunctions()
            validatedComponentFunctions = addConstantCompliments(componentFunctions)
        }
    }
    
    func removeAllComponents() {
        componentFunctions.removeAll()
        selectedComponentFunctions.removeAll()
        validatedComponentFunctions = addConstantCompliments(componentFunctions)
    }
    
    func removeSelectedComponents() {
        componentFunctions.removeAll { componentFunction in
            selectedComponentFunctions.contains(componentFunction.id)
        }
        selectedComponentFunctions.removeAll()
        
        validatedComponentFunctions = addConstantCompliments(componentFunctions)
    }
    
    func startEditing(_ id:UUID) {
        editingID = id
        let index = componentFunctions.firstIndex(where: {$0.id == id})!
        let componentFunction = componentFunctions[index]
        
        componentEditorObservable = ComponentEditorObservable(componentsEditorObservable:self)
        
        if let componentEditorObservable = componentEditorObservable {
                // copy the properties 
            componentEditorObservable.range = componentFunction.range
            
            componentEditorObservable.selectedTimeWarpFunctionType = componentFunction.timeWarpFunctionType.unflippedType()
            componentEditorObservable.isFlipped = componentFunction.timeWarpFunctionType.isFlipped()
            
            componentEditorObservable.factor = componentFunction.factor
            componentEditorObservable.modifier = componentFunction.modifier
            
                // set the frameRange
            componentEditorObservable.frameCountRange = frameCountRangeForRange(range: componentEditorObservable.range, videoFrameCount: videoFrameCount)
            
            componentEditorObservable.updateVideoRangeClip()
        }
        
        isEditing = true
    }
    
    func pausePlayers() {
        componentEditorObservable?.leftPlayer.pause()
        componentEditorObservable?.rightPlayer.pause()
    }
    
    func stopEditing(save:Bool) {
        pausePlayers()

        if save, let editingID = editingID, let componentEditorObservable = componentEditorObservable {
            let index = componentFunctions.firstIndex(where: {$0.id == editingID})!
            let range = rangeForFrameCountRange(frameCountRange: componentEditorObservable.frameCountRange, videoFrameCount: videoFrameCount)
            componentFunctions[index].range = range
            componentFunctions[index].timeWarpFunctionType = componentEditorObservable.timeWarpFunctionType()
            componentFunctions[index].factor = componentEditorObservable.factor
            componentFunctions[index].modifier = componentEditorObservable.modifier
            sortComponentFunctions()
            validatedComponentFunctions = addConstantCompliments(componentFunctions)
        }
        
        isEditing = false
        componentEditorObservable = nil
        
    }
    
    func deleteComponent(_ id:UUID) {
        let index = componentFunctions.firstIndex(where: {$0.id == id})!
        componentFunctions.remove(at: index)
        
        validatedComponentFunctions = addConstantCompliments(componentFunctions)
    }

    // Returns all ranges
    func componentFunctionRanges() -> [ClosedRange<Double>] {
        componentFunctions.map({ cf in
            cf.range
        })
    }
    
    // Returns validated and sorted ranges or nil
    func validateAndSortComponentFunctionRanges() -> [ClosedRange<Double>]? {    
        return validateAndSort(componentFunctionRanges())
    }
    
    // Returns all ranges available for new components - ie won't overlap
    func complimentOfComponentFunctionRanges() -> [ClosedRange<Double>]? {
        
        let ranges = componentFunctionRanges()
        
        if ranges.isEmpty {
            return [0.0...1.0]
        }
        
        return complimentOfRanges(ranges)
    }
    
    // First range available for new component
    func firstAvailableRangeForComponentFunction() -> ClosedRange<Double>? {
        return complimentOfComponentFunctionRanges()?.first
    }
    
    func isRangeAvailableForNewComponent() -> Bool {
        return firstAvailableRangeForComponentFunction() != nil
    }

}
