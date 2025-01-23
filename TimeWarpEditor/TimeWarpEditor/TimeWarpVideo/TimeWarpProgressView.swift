//
//  TimeWarpProgressView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpProgressView: View {
    
    @ObservedObject var timeWarpVideoObservable: TimeWarpVideoObservable
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        VStack {
            if let cgimage = timeWarpVideoObservable.progressFrameImage
            {
                Image(cgimage, scale: 1, label: Text("Preview"))
                    .resizable()
                    .scaledToFit()
            }
            else {
                Text("Processing…")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .scaleEffect(scale) // Adjusts the size
                    .animation(
                        Animation.easeInOut(duration: 0.8) // Smooth throbbing effect
                            .repeatForever(autoreverses: true),
                        value: scale
                    )
                    .onAppear {
                        scale = 1.2 // Start the throbbing by increasing the scale slightly
                    }
            }
            
            ProgressView(timeWarpVideoObservable.progressTitle, value: min(timeWarpVideoObservable.progress,1), total: 1)
                .padding()
                .frame(width: 300)
            
            Button("Cancel", action: { 
                timeWarpVideoObservable.cancel()
            }).padding()
        }
        
    }
}

struct TimeWarpProgressView_Previews: PreviewProvider {
    static var previews: some View {
        TimeWarpProgressView(timeWarpVideoObservable: TimeWarpVideoObservable())
    }
}
