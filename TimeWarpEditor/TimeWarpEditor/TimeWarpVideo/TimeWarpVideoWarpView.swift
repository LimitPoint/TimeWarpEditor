//
//  TimeWarpVideoWarpView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 7/22/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpingPathDetailsView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    
    var body: some View {
        Text(kTimeWarpingPathViewCaption)
            .font(.caption)
            .padding(.horizontal)
        
        Text("Time Warp on [0,1] to [\(String(format: "%.2f", timeWarpVideoObservable.timeWarpingPathViewObservable.minimum_y)), \(String(format: "%.2f", timeWarpVideoObservable.timeWarpingPathViewObservable.maximum_y))]\nExpected Time Warped Duration: \(timeWarpVideoObservable.expectedTimeWarpedDuration)")
            .font(.caption)
            .padding()
        
        Toggle(isOn: $timeWarpVideoObservable.fitPathInView) {
            Text("Fit Path In View")
        }
        .padding()
    }
}

struct SaveDoneButtonsView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    
    var body: some View {
        HStack {
            
            Button("Save", action: { 
                timeWarpVideoObservable.player.pause()
                timeWarpVideoObservable.timeWarpVideoDelegate?.timeWarpVideoDone()
            })
            .disabled(timeWarpVideoObservable.timeWarpedVideoURL == nil)
            .padding()
            
            if timeWarpVideoObservable.timeWarpedVideoURL == nil {
                Button("Cancel", action: { 
                    timeWarpVideoObservable.player.pause()
                    timeWarpVideoObservable.timeWarpVideoDelegate?.timeWarpVideoCancelled()
                }).padding()
            }
            else {
                Button(action: {
                    timeWarpVideoObservable.alertInfo = AlertInfo(id: .warnExitWithoutSavingWarpedVideo, title: "Leave without saving?", message: "The time warped video will be deleted.") 
                }, label: {
                    Text("Cancel")
                })
                .padding()
            }
        }
    }
}

struct EditTimeWarpButtonsView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    var componentsEditorObservable: ComponentsEditorObservable
    
    var body: some View {
        HStack {
            Button(action: { timeWarpVideoObservable.isComponentsEditing = true 
                componentsEditorObservable.videoURL = timeWarpVideoObservable.videoURL
                if let decodedComponents = DecodeComponentsFromUserDefaults(key: kTimeWarpEditorComponentFunctionsKey) {
                    componentsEditorObservable.componentFunctions = decodedComponents
                }
                timeWarpVideoObservable.player.pause() // stop playing
            }, label: {
                Label("Edit", systemImage: "slider.horizontal.3")
            })
            
            if timeWarpVideoObservable.timeWarpedVideoURL == nil {
                Button(action: { timeWarpVideoObservable.warp() }, label: {
                    Label("Time Warp", systemImage: "timelapse")
                })
            }
            else {
                Button(action: {
                    timeWarpVideoObservable.alertInfo = AlertInfo(id: .warnTimeWarpWillReplace, title: "Time Warp?", message: "The existing time warped video will be replaced.\n\nThis can not be undone.")
                }, label: {
                    Label("Time Warp", systemImage: "timelapse")
                })
                .padding()
            }
        }
        .padding()
    }
}

struct TimeWarpVideoWarpView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    var componentsEditorObservable: ComponentsEditorObservable
        
    var body: some View {
        ScrollView {
            VStack {
                
                TitleAndDescriptionView(title: kTimeWarpViewTitle, description: kTimeWarpViewDescription)
                
                ImportExportVideoView(timeWarpVideoObservable: timeWarpVideoObservable)
                
                if timeWarpVideoObservable.timeWarpVideoDelegate != nil {
                    SaveDoneButtonsView(timeWarpVideoObservable: timeWarpVideoObservable)
                }
                    
                VideoPlayerView(timeWarpVideoObservable: timeWarpVideoObservable)
                
                EditTimeWarpButtonsView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
                
                PlotAudioWaveformView(plotAudioObservable: timeWarpVideoObservable.plotAudioObservable)
                
                TimeWarpingPathView(timeWarpingPathViewObservable: timeWarpVideoObservable.timeWarpingPathViewObservable)
                    .padding()
                
                TimeWarpingPathDetailsView(timeWarpVideoObservable: timeWarpVideoObservable)
                
                FrameRateView(timeWarpVideoObservable: timeWarpVideoObservable)
                    .padding()
            }
            .alert(item: $timeWarpVideoObservable.alertInfo, content: { alertInfo in
                timeWarpVideoObservable.player.pause()
                if alertInfo.id == .warnExitWithoutSavingWarpedVideo {
                    return Alert(title: Text(alertInfo.title),
                          message: Text(alertInfo.message),
                          primaryButton: .cancel(),
                          secondaryButton: .destructive(Text("OK")) {
                        timeWarpVideoObservable.player.pause()
                        timeWarpVideoObservable.deleteTimeWarpedVideoURL()
                        timeWarpVideoObservable.timeWarpVideoDelegate?.timeWarpVideoCancelled()
                    })
                }
                else if alertInfo.id == .warnTimeWarpWillReplace {
                    return Alert(title: Text(alertInfo.title),
                                 message: Text(alertInfo.message),
                                 primaryButton: .cancel(),
                                 secondaryButton: .destructive(Text("OK")) {
                        timeWarpVideoObservable.warp()
                    })
                }
                else {
                    return Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
                }
            })
        }
    }
}

struct TimeWarpVideoWarpView_Previews: PreviewProvider {
    static var previews: some View {
        TimeWarpVideoWarpView(timeWarpVideoObservable: TimeWarpVideoObservable(), componentsEditorObservable: ComponentsEditorObservable(componentFunctions: [ComponentFunction()]))
    }
}
