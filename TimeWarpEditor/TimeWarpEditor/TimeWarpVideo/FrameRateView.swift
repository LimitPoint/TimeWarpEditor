//
//  FrameRateView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 7/22/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct FrameRateView: View {
    
    @ObservedObject var timeWarpVideoObservable: TimeWarpVideoObservable
    
    var body: some View {
        VStack {
            Picker("Frame Rate", selection: $timeWarpVideoObservable.fps) {
                Text("24").tag(FPS.twentyFour)
                Text("30").tag(FPS.thirty)
                Text("60").tag(FPS.sixty)
                Text("Any").tag(FPS.any)
            }
            .pickerStyle(.segmented)
            
            Text("\'Any\' is the natural rate due to variable time warping. Fixed rates are achieved by resampling.\n\nSee estimated FPS for 'Any' in plot caption above.")
                .font(.caption)
                .padding()
        }
    }
}

struct FrameRateView_Previews: PreviewProvider {
    static var previews: some View {
        FrameRateView(timeWarpVideoObservable: TimeWarpVideoObservable())
    }
}
