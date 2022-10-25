//
//  ComponentParametersView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 7/21/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ComponentParametersView: View {
    
    var componentFunction:ComponentFunction
    var vertical = true
    
    var body: some View {
        if vertical {
            VStack(alignment: .leading, spacing: 5) {
                Text(String(format: "Range: \(kRangePrecisonDisplay)", componentFunction.range.lowerBound) + "..." + String(format: kRangePrecisonDisplay, componentFunction.range.upperBound))
                    .font(.subheadline)
                Text(String(format: "Factor: %.2f", componentFunction.factor))
                    .font(.subheadline)
                if componentFunction.timeWarpFunctionType != .constant {
                    Text(String(format: "Modifer: %.2f", componentFunction.modifier))
                        .font(.subheadline)
                }
            }
        }
        else {
            HStack {
                Text(String(format: "Range: \(kRangePrecisonDisplay)", componentFunction.range.lowerBound) + "..." + String(format: kRangePrecisonDisplay, componentFunction.range.upperBound))
                    .font(.subheadline)
                Text(String(format: "Factor: %.2f", componentFunction.factor))
                    .font(.subheadline)
                if componentFunction.timeWarpFunctionType != .constant {
                    Text(String(format: "Modifer: %.2f", componentFunction.modifier))
                        .font(.subheadline)
                }
            }
        }
    }
}

struct ComponentParametersView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentParametersView(componentFunction: ComponentFunction())
    }
}
