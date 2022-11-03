//
//  RangeView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/30/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct RangeView: View {
    
    var range:ClosedRange<Double> = 0.25...0.75
    var size = 30.0
    
    var body: some View {
        
        GeometryReader { geometry in
            
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: range.lowerBound * geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.blue, lineWidth: size)
            
            Path { path in
                path.move(to: CGPoint(x: range.lowerBound * geometry.size.width, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: range.upperBound * geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.red, lineWidth: size)
            
            Path { path in
                path.move(to: CGPoint(x: range.upperBound * geometry.size.width, y: geometry.size.height / 2))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
            }
            .stroke(Color.blue, lineWidth: size)
        }
        
    }
}

struct LineView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RangeView(range: 0...0.5, size: 5)
            RangeView()
            RangeView(range: 0.5...1.0, size: 5)
        }
        
    }
}
