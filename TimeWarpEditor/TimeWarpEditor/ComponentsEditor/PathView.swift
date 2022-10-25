//
//  PathView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 5/1/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct PathView: View {
    var path:Path
    var size:CGSize
        
    var body: some View {
        GeometryReader { geometry in 
            path
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size.width, height: size.height)
    }
}

struct PathView_Previews: PreviewProvider {
    static var previews: some View {
        let size:Double = 64
        PathView(path: timeWarpingFunctionPath(currentTime: 0, pathViewFrameSize: CGSize(width: size, height: size), fitPathInView: false, componentFunction: ComponentFunction()), size: CGSize(width: size, height: size))
            .frame(width: size, height: size, alignment: .center)
    }
}

