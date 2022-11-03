//
//  TitleAndDescriptionView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 9/10/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TitleAndDescriptionView: View {
    
    var title:String
    var description:String
    
    @State private var isExpanded: Bool = kTitleAndDescriptionViewIsExpandedDefault
    
    var body: some View {
        VStack {
            Text(title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(2)
            
            DisclosureGroup("Info", isExpanded: $isExpanded) {
                Text(description)
                    .fontWeight(.regular)
                    .multilineTextAlignment(.leading)
                    .padding(2)
            }
        }
        .padding()
    }
}

struct TitleAndDescriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TitleAndDescriptionView(title: "Some Title", description: "Some Description")
    }
}
