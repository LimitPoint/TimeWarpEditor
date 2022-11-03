//
//  ComponentsEditorView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/25/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct ComponentsEditorSaveDoneView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    @State private var showCancelAlert = false
    
    var body: some View {
        HStack {
            Button(action: {
                timeWarpVideoObservable.isComponentsEditing = false
                timeWarpVideoObservable.validatedComponentFunctions = componentsEditorObservable.validatedComponents()
                EncodeComponentsToUserDefaults(key: kTimeWarpEditorComponentFunctionsKey, componentFunctions: componentsEditorObservable.componentFunctions)
            }, label: {
                Text("Save")
            })
            .padding()
            
            Button(action: {
                showCancelAlert = true
            }, label: {
                Text("Cancel")
            })
            .alert(isPresented: $showCancelAlert) {
                Alert(title: Text("Leave without saving?"),
                      message: Text("Any changes will be discarded."),
                      primaryButton: .cancel(),
                      secondaryButton: .destructive(Text("OK")) {
                    timeWarpVideoObservable.isComponentsEditing = false
                })
            }
            .padding()
        }
    }
}

struct ComponentsEditorPlotView: View {
    
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    var body: some View {
        if componentsEditorObservable.validatedComponentFunctions == nil {
            if componentsEditorObservable.componentFunctions.count != 0 {
                VStack {
                    Text("Invalid Components")
                    Text("Component ranges should be subintervals of unit interval, not overlap, have non-zero length.")
                }
            }
        }
        else {
            VStack {
                TimeWarpingPathView(timeWarpingPathViewObservable: componentsEditorObservable.timeWarpingPathViewObservable)
                    .padding()
                
                Text("Time Warp on [0,1] to [\(String(format: "%.2f", componentsEditorObservable.timeWarpingPathViewObservable.minimum_y)), \(String(format: "%.2f", componentsEditorObservable.timeWarpingPathViewObservable.maximum_y))]")
                    .font(.caption)
                    .padding()
                
                Toggle(isOn: $componentsEditorObservable.fitPathInView) {
                    Text("Fit Path In View")
                }
                .padding()
                
                RangesWithOverlayView(ranges: componentsEditorObservable.componentFunctionRanges(), size: 4, overlayRange: nil)
                    .frame(height: 4)
                    .padding()
                
                Text("Blue regions of timeline are available.")
                    .font(.caption)
            }
        }
    }
}

struct ComponentsEditorView: View {
    
    @ObservedObject var timeWarpVideoObservable:TimeWarpVideoObservable
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
        
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack {
                    
                    TitleAndDescriptionView(title: kComponentsEditorViewTitle, description: kComponentsEditorViewDescription)
                    
                    ComponentsEditorSaveDoneView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
                    
                    ComponentsTableView(componentsEditorObservable: componentsEditorObservable)
                        .padding()
                    
                    ComponentsTableButtonsView(componentsEditorObservable: componentsEditorObservable)
                    
                    ComponentsEditorPlotView(componentsEditorObservable: componentsEditorObservable)
                }
            }
            .onChange(of: componentsEditorObservable.scrollToID) { _ in
                if let id = componentsEditorObservable.scrollToID {
                    proxy.scrollTo(id)
                }
            }
        }
    }
}

struct ComponentsEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentsEditorView(timeWarpVideoObservable: TimeWarpVideoObservable(), componentsEditorObservable: ComponentsEditorObservable(componentFunctions: [ComponentFunction(range: 0...0.25), ComponentFunction(range: 0.25...0.50), ComponentFunction(range: 0.50...0.75), ComponentFunction(range: 0.75...1.0)]))
    }
}
