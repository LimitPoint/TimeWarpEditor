//
//  ImportExportVideoView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 7/14/22. 
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import AVKit

let tangerine = Color(red: 0.98, green: 0.57, blue: 0.21, opacity:0.9)

struct ImportExportVideoView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable 
    
    @State private var showFileImporter: Bool = false
    @State private var showFileExporter: Bool = false
    
    @State private var showURLLoadingProgress = false
    
    var body: some View {
        VStack {
            
            if timeWarpVideoObservable.timeWarpVideoDelegate == nil {
                HStack {
                    
                    Button(action: { timeWarpVideoObservable.loadAndPlayURL(kDefaultURL) }, label: {
                        Label("Default", systemImage: "cube.fill")
                    })
                    
                    Button(action: { timeWarpVideoObservable.loadAndPlayURL(kFireworksURL) }, label: {
                        Label("Fireworks", systemImage: "flame")
                    })
                    
                    Button(action: { timeWarpVideoObservable.loadAndPlayURL(kTwistsURL) }, label: {
                        Label("Music", systemImage: "music.note")
                    })
                }
                .padding()
            }
            
            HStack {
                Button(action: { showFileImporter = true }, label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                })
                
                Button(action: { 
                    if timeWarpVideoObservable.prepareToExportTimeWarpedVideo() {
                        showFileExporter = true 
                    }
                }, label: {
                    Label("Export", systemImage: "square.and.arrow.up.fill")
                })
            }
            
        }
        .padding()
        .fileExporter(isPresented: $showFileExporter, document: timeWarpVideoObservable.videoDocument, contentType: UTType.quickTimeMovie, defaultFilename: timeWarpVideoObservable.videoDocument?.filename) { result in
            if case .success = result {
                do {
                    let exportedURL: URL = try result.get()
                    timeWarpVideoObservable.alertInfo = AlertInfo(id: .exporterSuccess, title: "Time Warped Video Saved", message: exportedURL.lastPathComponent)
                }
                catch {
                    
                }
            } else {
                timeWarpVideoObservable.alertInfo = AlertInfo(id: .exporterFailed, title: "Time Warped Video Not Saved", message: (timeWarpVideoObservable.videoDocument?.filename ?? ""))
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.movie, .quickTimeMovie, .mpeg4Movie], allowsMultipleSelection: false) { result in
            do {
                showURLLoadingProgress = true
                guard let selectedURL: URL = try result.get().first else { return }
                timeWarpVideoObservable.saveLastImportedFilename(selectedURL)
                timeWarpVideoObservable.loadSelectedURL(selectedURL) { wasLoaded in
                    if !wasLoaded {
                        timeWarpVideoObservable.alertInfo = AlertInfo(id: .urlNotLoaded, title: "Video Not Loaded", message: (timeWarpVideoObservable.errorMesssage ?? "No information available."))
                    }
                    showURLLoadingProgress = false
                }
            } catch {
                print(error.localizedDescription)
            }
        }
        .alert(item: $timeWarpVideoObservable.alertInfo, content: { alertInfo in
            Alert(title: Text(alertInfo.title), message: Text(alertInfo.message))
        })
        .overlay(Group {
            if showURLLoadingProgress {          
                ProgressView("Loading...")
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(tangerine))
            }
        })
    }
}

struct ImportExportVideoView_Previews: PreviewProvider {
    static var previews: some View {
        ImportExportVideoView(timeWarpVideoObservable: TimeWarpVideoObservable())
    }
}
