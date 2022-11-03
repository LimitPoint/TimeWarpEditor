//
//  VideoPlayerView.swift
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

struct VideoPlayerView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable 
    
    var body: some View {
        VStack {
            VideoPlayer(player: timeWarpVideoObservable.player)
                .frame(minHeight: 300)
            
            // caption
            if timeWarpVideoObservable.playingTimeWarped == true {
                Text("〰 Warped")
            }
            else {
                Text("⎯ Original")
            }
            
            HStack {
                Button(action: { timeWarpVideoObservable.playOriginal() }, label: {
                    Label("Original", systemImage: "play.circle")
                })
                
                Button(action: { timeWarpVideoObservable.playTimeWarped() }, label: {
                    Label("Time Warped", systemImage: "play.circle.fill")
                })
                
            }
            .padding()
        }
    }
}

struct VideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        VideoPlayerView(timeWarpVideoObservable: TimeWarpVideoObservable())
    }
}
