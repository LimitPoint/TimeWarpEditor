//
//  TimeWarpingPathView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 7/12/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpingPathView: View {
    
    @ObservedObject var timeWarpingPathViewObservable:TimeWarpingPathViewObservable
    
    var body: some View {
        // geometry used to center the paths
        GeometryReader {  geometry in
            
            Path { path in
                path.addRect(CGRect(origin: CGPoint(x: 0, y: 0), size: /*geometry.size*/ timeWarpingPathViewObservable.timeWarpingPathSize))
            }
            .stroke(Color(red: 0.0, green: 0, blue: 0.0, opacity: 0.2), style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .background(Color(red: 1, green: 1, blue: 1, opacity: 0.5)) // make tappable
            .gesture(DragGesture(minimumDistance: 0).onEnded({ (value) in
                timeWarpingPathViewObservable.tapped(value.location)
            }))
            
            // all components path
            timeWarpingPathViewObservable.allComponentsPath
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            
            // selected components
            ForEach(timeWarpingPathViewObservable.componentPaths) { componentPath in 
                if timeWarpingPathViewObservable.selectedComponentFunctions.contains(componentPath.id) {
                    componentPath.path
                        .stroke(Color.red, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .frame(width: timeWarpingPathViewObservable.timeWarpingPathSize.width, height: timeWarpingPathViewObservable.timeWarpingPathSize.height, alignment: Alignment.center)
        .overlay(Text("\(String(format: "%.2f", timeWarpingPathViewObservable.maximum_y))"), alignment: .top)
        .overlay(Text("\(String(format: "%.2f", timeWarpingPathViewObservable.minimum_y))"), alignment: .bottom)
    }
}

struct TimeWarpingPathView_Previews: PreviewProvider {
    
    static var previews: some View {
        TimeWarpingPathView(timeWarpingPathViewObservable: TimeWarpingPathViewObservable(indicatorAtZero: true, fitPathInView: false))
    }
}
