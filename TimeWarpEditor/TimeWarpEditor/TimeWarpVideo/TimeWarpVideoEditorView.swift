//
//  TimeWarpVideoEditorView.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 7/22/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct TimeWarpVideoEditorView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    var body: some View {
        if componentsEditorObservable.isEditing {
            ComponentEditorView(componentEditorObservable: componentsEditorObservable.componentEditorObservable!)
        }
        else {
            ComponentsEditorView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
        }
    }
}

struct TimeWarpVideoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        TimeWarpVideoEditorView(timeWarpVideoObservable: TimeWarpVideoObservable(), componentsEditorObservable: ComponentsEditorObservable(componentFunctions: [ComponentFunction()]))
    }
}
