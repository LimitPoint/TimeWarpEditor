//
//  ComponentEditorView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/25/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import AVKit

struct ComponentEditorButtonView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var showCantSaveComponentAlert = false
    @State private var showCancelAlert = false
    
    var body: some View {
        HStack {
            Button(action: {
                if componentEditorObservable.componentEditorFrameRangeIsValid() {
                    componentEditorObservable.componentsEditorObservable.stopEditing(save:true)
                }
                else {
                    showCantSaveComponentAlert = true
                }
            }, label: {
                Text("Save")
            })
            .alert(isPresented: $showCantSaveComponentAlert) {
                Alert(title: Text("Can't Save Component"), message: Text("The selected range overlaps existing components."), dismissButton: Alert.Button.cancel())
            }
            .padding()
            
            Button(action: {
                    // alert doesn't function if video is playing?
                componentEditorObservable.leftPlayer.pause() 
                componentEditorObservable.rightPlayer.pause()
                showCancelAlert = true
            }, label: {
                Text("Cancel")
            })
            .alert(isPresented: $showCancelAlert) {
                Alert(title: Text("Leave without saving?"),
                      message: Text("Any changes will be discarded."),
                      primaryButton: .cancel(),
                      secondaryButton: .destructive(Text("OK")) {
                    componentEditorObservable.componentsEditorObservable.stopEditing(save:false)
                })
            }
            .padding()
        }
    }
}

struct PreviewButtonView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var showCantPreviewComponentAlert = false
    
    var body : some View {
        Button(action: { 
            if componentEditorObservable.componentEditorFrameRangeIsValid() {
                componentEditorObservable.startPreviewing()
            }
            else {
                showCantPreviewComponentAlert = true
            }
        }, label: {
            Label("Preview", systemImage: "eye.square.fill")
        })
        .alert(isPresented: $showCantPreviewComponentAlert) {
            Alert(title: Text("Can't Preview Component"), message: Text("The selected range overlaps existing components."), dismissButton: Alert.Button.cancel())
        }
        .padding()
    }
}

struct ComponentEditorHeaderView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    var body: some View {
        VStack {
            TitleAndDescriptionView(title: kComponentEditorViewTitle, description: kComponentEditorViewDescription)
            
            ComponentEditorButtonView(componentEditorObservable: componentEditorObservable)
        }
    }
}

struct ComponentEditorRangeView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    var body: some View {
        VStack {
            ValidRangeView(ok: componentEditorObservable.componentEditorFrameRangeIsValid(), width: 10)
            
            RangesWithOverlayView(ranges: componentEditorObservable.componentEditorFrameRanges(), size: 4, overlayRange: rangeForFrameCountRange(frameCountRange: componentEditorObservable.frameCountRange, videoFrameCount: componentEditorObservable.componentsEditorObservable.videoFrameCount))
                .frame(height: 4)
                .padding()
            
            ComponentRangeView(componentEditorObservable: componentEditorObservable)
        }
    }
}

struct ComponentEditorComponentTypeView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var isComponentTypeExpanded: Bool = true
    @State private var isDetailsExpanded: Bool = true
    
    var body: some View {
        
        DisclosureGroup("Component Type", isExpanded: $isComponentTypeExpanded) {
            VStack {
                TimeWarpingPathView(timeWarpingPathViewObservable: componentEditorObservable.timeWarpingPathViewObservable)
                    .frame(minHeight: kTimeWarpingPathDimension)
                    .padding()
                
                DisclosureGroup("Details", isExpanded: $isDetailsExpanded) {
                    ComponentParametersView(componentFunction: componentEditorObservable.component, vertical: false)
                    
                    Text("Time Warp on [0,1] to [\(String(format: "%.2f", componentEditorObservable.timeWarpingPathViewObservable.minimum_y)), \(String(format: "%.2f", componentEditorObservable.timeWarpingPathViewObservable.maximum_y))]")
                        .font(.caption)
                        .padding()
                    
                    Toggle(isOn: $componentEditorObservable.fitPathInView) {
                        Text("Fit Path In View")
                    }
                    .padding()
                }
                
                ComponentOptionsView(componentEditorObservable: componentEditorObservable)
                    .frame(minHeight: 300)
            }
        }
    }
}

struct VideoPlayerWithPlayButtonView: View {
    
    var player:AVPlayer
    
    var body: some View {
        VStack(alignment: .center) {
            VideoPlayer(player: player)
                .frame(minHeight: 300)
            HStack {
                Button(action: {
                    player.seek(to: CMTime.zero, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
                    player.play() 
                }) {
                    Image(systemName: "gobackward")
                }
                Spacer()
                Button(action: {
                    player.play() 
                }) {
                    Image(systemName: "play.circle")
                }
                Spacer()
                Button(action: {
                    player.pause() 
                }) {
                    Image(systemName: "stop.circle")
                }
            }
            .padding()
        }
    }
}

struct ComponentEditorVideoRangeView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var isExpanded: Bool = true
    
    var body: some View {
        DisclosureGroup("Video Clip Range", isExpanded: $isExpanded) {
            VideoPlayerWithPlayButtonView(player: componentEditorObservable.videoRangeClipPlayer)
        }
    }
}

struct ComponentEditorView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    var body: some View {
        ScrollView {
            if componentEditorObservable.isPreviewing {
                ComponentEditorPreviewView(componentEditorPreviewObservable: componentEditorObservable.componentEditorPreviewObservable!)
            }
            else {
                VStack {
                    
                    ComponentEditorHeaderView(componentEditorObservable: componentEditorObservable)
                
                    ComponentEditorRangeView(componentEditorObservable: componentEditorObservable)
                    
                    PreviewButtonView(componentEditorObservable: componentEditorObservable)
                    
                    ComponentEditorComponentTypeView(componentEditorObservable: componentEditorObservable)
                        .padding()
                    
                    ComponentEditorVideoRangeView(componentEditorObservable: componentEditorObservable)
                        .padding()
                }
            }
        }
    }
}

struct ComponentEditorView_Previews: PreviewProvider {
    static var previews: some View {
        
        ComponentEditorView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
        /*
        ComponentEditorHeaderView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
        
        ComponentEditorRangeView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
        
        PreviewButtonView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
        
        ScrollView {
         ComponentEditorComponentTypeView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
                .padding()
        }
        
        ScrollView {
         ComponentEditorVideoRangeView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
                .padding()
        }
         */
        
    }
}
