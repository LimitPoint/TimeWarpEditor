//
//  ValidRangeView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 7/5/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ValidRangeView: View {
    
    var ok:Bool
    var width:Double
    
    var body: some View {
        VStack {
            HStack {
                if ok {
                    Circle()
                        .frame(width: width, height: width)
                        .foregroundColor(Color.green)
                }
                else {
                    VStack {
                        Circle()
                            .frame(width: width, height: width)
                            .foregroundColor(Color.red)
                    }
                    
                }
                
                (ok ? Text("Valid Range") : Text("Invalid Range"))
            }
            
            if ok == false {
                Text("The range overlaps a neighboring range")
                    .font(.caption)
            }
        }
    }
}

struct ValidRangeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ValidRangeView(ok: true, width: 30)
            ValidRangeView(ok: false, width: 15)
        }
    }
}
