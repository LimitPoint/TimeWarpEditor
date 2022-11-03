//
//  MultiLineView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 7/04/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct RangesWithOverlayView: View {
    
    var ranges:[ClosedRange<Double>] = [0.24...0.76]
    var size = 30.0
    var overlayRange:ClosedRange<Double>?
    
    var body: some View {
        
        GeometryReader { geometry in
            
            // draw full blue line
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.blue, lineWidth: size)
            
            // draw red line for each range
            //for range in ranges {
            ForEach(ranges, id: \.self) { range in
                Path { path in
                    path.move(to: CGPoint(x: range.lowerBound * geometry.size.width, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: range.upperBound * geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(Color.red, lineWidth: size)
            }
            
            if let overlayRange = overlayRange {
                let overlayColor = Color.black.opacity(0.3)
                Path { path in
                    path.move(to: CGPoint(x: overlayRange.lowerBound * geometry.size.width, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: overlayRange.upperBound * geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: size, lineCap: .butt))
                .foregroundColor(overlayColor)
            }
        }
    }
}

struct RangesWithOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RangesWithOverlayView(ranges: [0.0...0.2, 0.4...0.6, 0.8...1.0], size: 5)
            RangesWithOverlayView(ranges: [0.25...0.75], overlayRange: 0.50...0.90)
            RangesWithOverlayView(ranges: [0.0...0.1, 0.2...0.3, 0.4...0.5, 0.6...0.7, 0.8...0.9], size: 10)
        }
    }
}
