//
//  TimeWarpProgressView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpProgressView: View {
    
    @ObservedObject var timeWarpVideoObservable: TimeWarpVideoObservable
    
    var body: some View {
        VStack {
            if let cgimage = timeWarpVideoObservable.progressFrameImage
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
