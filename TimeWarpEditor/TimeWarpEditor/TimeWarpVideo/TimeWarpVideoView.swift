//
//  TimeWarpVideoView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpVideoView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    var componentsEditorObservable: ComponentsEditorObservable
    
    var body: some View {
        if timeWarpVideoObservable.isTimeWarping {
            TimeWarpProgressView(timeWarpVideoObservable: timeWarpVideoObservable)
        }
        else {
            if timeWarpVideoObservable.isComponentsEditing {
                TimeWarpVideoEditorView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
            }
            else {
                TimeWarpVideoWarpView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
            }
        }
    }
}

struct TimeWarpVideoView_Previews: PreviewProvider {
    static var previews: some View {
        TimeWarpVideoView(timeWarpVideoObservable: TimeWarpVideoObservable(), componentsEditorObservable: ComponentsEditorObservable(componentFunctions: [ComponentFunction()]))
    }
}
