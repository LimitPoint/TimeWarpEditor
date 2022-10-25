//
//  ComponentRangeView.swift
//  ComponentsEditor
//
//  Created by Joseph Pagliaro on 7/1/22.
//

import SwiftUI
import AVKit

let frameIncrementValues:[Int] = [1,3,5,10,30,60,90,120,240]

struct FrameIncrementPickerView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
        
    var body: some View {
        VStack {
            Picker("", selection: $componentEditorObservable.frameIncrementValue) {
                ForEach(frameIncrementValues, id: \.self) { value in
                    Text("\(value)")
                }
            }
            .frame(width: 100)
            
            Text("Frame Increment")
                .font(.caption)
            
            Text("\(String(format: kRangePrecisonDisplay, componentEditorObservable.frameIncrementSeconds())) sec")
                .font(.system(size: 10))
        }
    }
}

struct MatchFitRangeView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    var body: some View {
        VStack {
            Button(action: {
                componentEditorObservable.matchFitRangetoAvailableRanges()
            }, label: {
                Image(systemName: "wand.and.stars")
            })
            .buttonStyle(BorderlessButtonStyle())
            .font(.system(size: 32, weight: .light))
            .frame(width: 44, height: 44)
            
            Text("Fit")
                .font(.caption)
        }
    }
}

struct ComponentRangeView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    var body: some View {
        VStack {
            HStack {
                VideoPlayerWithPlayButtonView(player: componentEditorObservable.leftPlayer)
                VideoPlayerWithPlayButtonView(player: componentEditorObservable.rightPlayer)
            }
            
            VStack {
                VStack {
                    Text("Time Range: \(secondsToString(secondsIn: componentEditorObservable.range.lowerBound * componentEditorObservable.componentsEditorObservable.videoDuration))...\(secondsToString(secondsIn: componentEditorObservable.range.upperBound * componentEditorObservable.componentsEditorObservable.videoDuration))")
    
                    Text("Duration: \(secondsToString(secondsIn: componentEditorObservable.range.upperBound * componentEditorObservable.componentsEditorObservable.videoDuration - componentEditorObservable.range.lowerBound * componentEditorObservable.componentsEditorObservable.videoDuration))")
                        .font(.caption)
                    
                    Text("[\(String(format: kRangePrecisonDisplay, rangeForFrameCountRange(frameCountRange: componentEditorObservable.frameCountRange, videoFrameCount: componentEditorObservable.componentsEditorObservable.videoFrameCount).lowerBound))...\(String(format: kRangePrecisonDisplay, rangeForFrameCountRange(frameCountRange: componentEditorObservable.frameCountRange, videoFrameCount: componentEditorObservable.componentsEditorObservable.videoFrameCount).upperBound))]")
                        .font(.caption)
                }
            }
            .padding()
            
            PlotAudioWaveformView(plotAudioObservable: componentEditorObservable.plotAudioObservable)
            
            Button(action: {
                componentEditorObservable.componentsEditorObservable.pausePlayers()
                componentEditorObservable.syncPlayerTimesToRange()
            }, label: {
                HStack {
                    Image(systemName: "arrow.up")
                    Text("Reapply Range to Players")
                }
                
            })
            .padding(2)
            
            RangedSliderView(frameCount: Int(componentEditorObservable.componentsEditorObservable.videoFrameCount), frameCountRange: $componentEditorObservable.frameCountRange, displayRangeForFrameCountRange: rangeForFrameCountRange, rangedSliderViewDelegate: componentEditorObservable)
                .padding()
            
            HStack {
                HStack {
                    Button(action: {
                        componentEditorObservable.decrementRangeLeft()
                    }, label: {
                        Image(systemName: "minus.square")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 44, height: 44)
                    .disabled(!componentEditorObservable.canDecrementRangeLeft())
                    
                    Button(action: {
                        componentEditorObservable.incrementRangeLeft()
                    }, label: {
                        Image(systemName: "plus.square")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 44, height: 44)
                    .disabled(!componentEditorObservable.canIncrementRangeLeft())
                }
                
                Spacer()
                
                MatchFitRangeView(componentEditorObservable: componentEditorObservable)
                
                Spacer()
                
                FrameIncrementPickerView(componentEditorObservable: componentEditorObservable)
                
                Spacer()
                
                HStack {
                    Button(action: {
                        componentEditorObservable.decrementRangeRight()
                    }, label: {
                        Image(systemName: "minus.square")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 44, height: 44)
                    .disabled(!componentEditorObservable.canDecrementRangeRight())
                    
                    Button(action: {
                        componentEditorObservable.incrementRangeRight()
                    }, label: {
                        Image(systemName: "plus.square")
                    })
                    .buttonStyle(BorderlessButtonStyle())
                    .font(.system(size: 32, weight: .light))
                    .frame(width: 44, height: 44)
                    .disabled(!componentEditorObservable.canIncrementRangeRight())
                }
            }
            .padding()
        }
    }
}

struct ComponentRangeView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentRangeView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
    }
}
