//
//  ComponentsTableViewRowView.swift
//  ComponentsEditor
//
//  Created by Joseph Pagliaro on 6/25/22.
//

import SwiftUI

let kTimeWarpingPathSizeDimension = 64

struct ComponentsTableViewRowView: View {
    
    var componentFunction:ComponentFunction
    
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    @State private var showDeleteAlert = false
    
    var timeWarpingPathSize:CGSize = CGSize(width: kTimeWarpingPathSizeDimension, height: kTimeWarpingPathSizeDimension)
    
    var body: some View {
        
        VStack {
            Text(componentFunction.timeWarpFunctionType.rawValue)
                .font(.headline)
            
            HStack {
                
                ComponentParametersView(componentFunction: componentFunction)
                
                VStack {
                    
                    HStack {
                        Button(action: {
                            componentsEditorObservable.startEditing(componentFunction.id)
                        }, label: {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                        })
                        .buttonStyle(BorderlessButtonStyle()) // need this or tapping one invokes both actions
                        
                        Button(action: {
                            showDeleteAlert = true
                        }, label: {
                            Image(systemName: "trash.fill")
                                .imageScale(.large)
                        })
                        .buttonStyle(BorderlessButtonStyle()) // need this or tapping one invokes both actions
                        .alert(isPresented: $showDeleteAlert) {
                            Alert(title: Text("Delete component?"),
                                  primaryButton: .cancel(),
                                  secondaryButton: .destructive(Text("Delete")) {
                                componentsEditorObservable.deleteComponent(componentFunction.id)
                            })
                        }
                        .padding()
                    }
                    
                    PathView(path: timeWarpingFunctionPath(currentTime: 0, pathViewFrameSize: timeWarpingPathSize, fitPathInView: false, componentFunction: componentFunction), size: timeWarpingPathSize)
                        .frame(minHeight: timeWarpingPathSize.height)
                    
                    RangeView(range: componentFunction.range, size: 4)
                        .frame(height: 4)
                    
                    Text("\(secondsToString(secondsIn: componentFunction.range.lowerBound * componentsEditorObservable.videoDuration))...\(secondsToString(secondsIn: componentFunction.range.upperBound * componentsEditorObservable.videoDuration))")
                }
                
            }
        }
    }
}

struct ComponentsTableViewRowView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentsTableViewRowView(componentFunction: ComponentFunction(), componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()]))
            .frame(height: 150)
    }
}
