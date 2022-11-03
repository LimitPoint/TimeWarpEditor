//
//  ComponentsTableView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/25/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ComponentsTableView: View {
    
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    var body: some View {
        if componentsEditorObservable.componentFunctions.count == 0 {
            Text("No Component Functions")
                .padding()
        }
        else {
            VStack {
                ForEach(componentsEditorObservable.componentFunctions) { componentFunction in
                    ComponentsTableViewRowView(componentFunction: componentFunction, componentsEditorObservable: componentsEditorObservable)
                        .background(componentsEditorObservable.selectedComponentFunctions.contains(componentFunction.id) ? Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.5) : Color(red: 1, green: 1, blue: 1, opacity: 0.5))
                        .onTapGesture {
                            if componentsEditorObservable.selectedComponentFunctions.contains(componentFunction.id) {
                                componentsEditorObservable.selectedComponentFunctions.remove(componentFunction.id)
                            }
                            else {
                                componentsEditorObservable.selectedComponentFunctions.insert(componentFunction.id)
                            }
                        }
                        .padding()
                }
            }
        }
    }
}

struct ComponentsTableView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentsTableView(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction(range: 0...0.25), ComponentFunction(range: 0.25...0.50), ComponentFunction(range: 0.50...0.75), ComponentFunction(range: 0.75...1.0)]))
    }
}
