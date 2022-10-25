//
//  ComponentEditorPreviewView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 8/20/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import AVKit

struct PathDetailsView: View {
    
    @ObservedObject var componentEditorPreviewObservable: ComponentEditorPreviewObservable
    
    var body: some View {
        Text(kTimeWarpingPathViewCaption)
            .font(.caption)
            .padding(.horizontal)
        
        Text("Time Warp on [0,1] to [\(String(format: "%.2f", componentEditorPreviewObservable.timeWarpingPathViewObservable.minimum_y)), \(String(format: "%.2f", componentEditorPreviewObservable.timeWarpingPathViewObservable.maximum_y))]\nExpected Time Warped Duration: \(componentEditorPreviewObservable.expectedTimeWarpedDuration)")
            .font(.caption)
            .padding()
        
        Toggle(isOn: $componentEditorPreviewObservable.fitPathInView) {
            Text("Fit Path In View")
        }
        .padding()
    }
}

struct ComponentEditorPreviewView: View {
    
    @ObservedObject var componentEditorPreviewObservable: ComponentEditorPreviewObservable
    
    var body: some View {
        VStack {
            
            TitleAndDescriptionView(title: kComponentPreviewViewTitle, description: kComponentPreviewViewDescription)
            
            if componentEditorPreviewObservable.isTimeWarping {
                
                if let cgimage = componentEditorPreviewObservable.progressFrameImage
                {
                    Image(cgimage, scale: 1, label: Text("Preview"))
                        .resizable()
                        .scaledToFit()
                }
                else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100, alignment: .center)
                }
                
                ProgressView(componentEditorPreviewObservable.progressTitle, value: min(componentEditorPreviewObservable.progress,1), total: 1)
                    .padding()
                    .frame(width: 300)
                
                Button("Cancel", action: { 
                    componentEditorPreviewObservable.cancel()
                }).padding()
            }
            else {
                Button("Done", action: { 
                    componentEditorPreviewObservable.cancel()
                }).padding()
                
                if componentEditorPreviewObservable.errorMessage != nil {
                    VStack(alignment: .center) {
                        Image(systemName: "xmark.octagon")
                            .imageScale(.large)
                        Text("An error occured!")
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(2)
                        Text(componentEditorPreviewObservable.errorMessage!)
                            .padding()
                    }
                }
                else {
                    
                    if componentEditorPreviewObservable.videoClipIsLandscape() {
                        VStack {
                            Text(kWarpedVideoClipTitle)
                            VideoPlayerWithPlayButtonView(player: componentEditorPreviewObservable.warpedVideoPlayer)
                            
                            TimeWarpingPathView(timeWarpingPathViewObservable: componentEditorPreviewObservable.timeWarpingPathViewObservable)
                                .padding()
                            
                            PathDetailsView(componentEditorPreviewObservable: componentEditorPreviewObservable)
                            
                            Text(kVideoClipTitle)
                            VideoPlayerWithPlayButtonView(player: componentEditorPreviewObservable.videoRangeClipPlayer)
                        }
                    }
                    else {
                        VStack {
                            HStack {
                                VStack {
                                    Text(kWarpedVideoClipTitle)
                                    VideoPlayerWithPlayButtonView(player: componentEditorPreviewObservable.warpedVideoPlayer)
                                }
                                VStack {
                                    Text(kVideoClipTitle)
                                    VideoPlayerWithPlayButtonView(player: componentEditorPreviewObservable.videoRangeClipPlayer)
                                }
                            }
                            
                            TimeWarpingPathView(timeWarpingPathViewObservable: componentEditorPreviewObservable.timeWarpingPathViewObservable)
                                .padding()
                            
                            PathDetailsView(componentEditorPreviewObservable: componentEditorPreviewObservable)
                        }
                    }
                }
            }
        }
        .onAppear {
            componentEditorPreviewObservable.warpPreview()
        }
    }
}

struct ComponentEditorPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentEditorPreviewView(componentEditorPreviewObservable: ComponentEditorPreviewObservable(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(videoURL: kDefaultVideoURL, componentFunctions: [ComponentFunction()]))))
    }
}
