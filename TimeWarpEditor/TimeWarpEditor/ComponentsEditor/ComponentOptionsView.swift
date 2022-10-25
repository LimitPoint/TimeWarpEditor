//
//  ComponentOptionsView.swift
//  ComponentsEditor
//
//  Created by Joseph Pagliaro on 3/15/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI

struct OptionsPickerView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
        
    var body: some View {
        VStack {
            Picker("Time Warping", selection: $componentEditorObservable.selectedTimeWarpFunctionType) {
                ForEach(TimeWarpFunctionType.allUnFlipped()) { timeWarpFunctionType in
                    if timeWarpFunctionType != .constantCompliment {
                        Text(timeWarpFunctionType.rawValue)
                    }
                }
            }
            
            Toggle(isOn: $componentEditorObservable.isFlipped) {
                Text("Flipped")
            }
            .padding()
            .disabled(componentEditorObservable.selectedTimeWarpFunctionType.flippedType() == nil)
            
            Text("Select an instantaneous time warping function.\nUse Factor and Modifier parameters to customize it.")
                .font(.caption)
                .padding(1)
        }
    }
}

struct FactorView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var editingChanged = false
    
    var body: some View {
        VStack {
            Text(String(format: "%.2f", componentEditorObservable.factor))
                .foregroundColor(editingChanged ? .red : .blue)
            
            Slider(
                value: $componentEditorObservable.factor,
                in: 0.1...kComponentFactorMax
            ) {
                Text("Factor")
            } minimumValueLabel: {
                Text("0.1")
            } maximumValueLabel: {
                Text(String(format: "%.1f", kComponentFactorMax))
            } onEditingChanged: { editing in
                editingChanged = editing
            }
            
            Text("See plot above to see effect of factor on it.")
                .font(.caption)
                .padding()
        }
    }
}

struct ModiferView: View {
    
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
    
    @State private var editingChanged = false
    
    var body: some View {
        
        if componentEditorObservable.selectedTimeWarpFunctionType == .constant {
            Text("Constant time warping has no modifer.")
        }
        else {
            VStack {
                Text(String(format: "%.2f", componentEditorObservable.modifier))
                    .foregroundColor(editingChanged ? .red : .blue) 
                Slider(
                    value: $componentEditorObservable.modifier,
                    in: 0.1...1
                ) {
                    Text("Modifier")
                } minimumValueLabel: {
                    Text("0.1")
                } maximumValueLabel: {
                    Text("1")
                } onEditingChanged: { editing in
                    editingChanged = editing
                }
                
                Text("See plot above to see effect of modifier on it.")
                    .font(.caption)
                    .padding()
            }
        }
    }
}


struct ComponentOptionsView: View {
    @ObservedObject var componentEditorObservable: ComponentEditorObservable
        
    var body: some View {
        TabView {
            OptionsPickerView(componentEditorObservable: componentEditorObservable)
                .tabItem {
                    Image(systemName: "function")
                    Text("Warp Type")
                }
            
            FactorView(componentEditorObservable: componentEditorObservable)
                .tabItem {
                    Image(systemName: "f.circle.fill")
                    Text("Factor")
                }
            
            ModiferView(componentEditorObservable: componentEditorObservable)
                .tabItem {
                    Image(systemName: "m.circle.fill")
                    Text("Modifer")
                }
        }
        .padding()
    }
}

struct ComponentOptionsView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentOptionsView(componentEditorObservable: ComponentEditorObservable(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()])))
    }
}
