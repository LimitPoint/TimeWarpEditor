//
//  ComponentsTableButtonsView.swift
//  ComponentsEditor
//
//  Created by Joseph Pagliaro on 6/25/22.
//

import SwiftUI

struct ComponentsTableButtonsView: View {
    
    @ObservedObject var componentsEditorObservable: ComponentsEditorObservable
    
    @State private var showCantAddComponentAlert = false
    @State private var showRemoveAllAlert = false
    @State private var showRemoveSelectedAlert = false
    
    var body: some View {
        HStack {
            // Add
            Button(action: {
                if componentsEditorObservable.isRangeAvailableForNewComponent() {
                    componentsEditorObservable.addComponent()
                }
                else {
                    showCantAddComponentAlert = true
                }
            }, label: {
                Image(systemName: "plus.circle")
            })
            .alert(isPresented: $showCantAddComponentAlert) {
                Alert(title: Text("Can't Add New Component"), message: Text("Existing components cover the whole time range of the video.\nEdit the ranges of existing components to make room and try again."), dismissButton: Alert.Button.cancel())
            }
            .padding()
            
            // Remove All
            if componentsEditorObservable.componentFunctions.count > 0 {
                Button(action: {
                    showRemoveAllAlert = true
                }, label: {
                    Image(systemName: "trash.fill")
                })
                .alert(isPresented: $showRemoveAllAlert) {
                    Alert(title: Text("Remove all components?"),
                          message: Text("This cannot be undone."),
                          primaryButton: .cancel(),
                          secondaryButton: .destructive(Text("Remove All")) {
                        componentsEditorObservable.removeAllComponents()
                    })
                }
                .padding()
            }
            
            // Remove Selected
            if componentsEditorObservable.selectedComponentFunctions.count > 0 {
                Button(action: {
                    showRemoveSelectedAlert = true
                }, label: {
                    Image(systemName: "minus.circle.fill")
                })
                .alert(isPresented: $showRemoveSelectedAlert) {
                    Alert(title: Text("Remove selected components?"),
                          message: Text("This cannot be undone."),
                          primaryButton: .cancel(),
                          secondaryButton: .destructive(Text("Remove Selected")) {
                        componentsEditorObservable.removeSelectedComponents()
                    })
                }
                .padding()
            }
        }
    }
}

struct ComponentsTableButtonsView_Previews: PreviewProvider {
    static var previews: some View {
        ComponentsTableButtonsView(componentsEditorObservable: ComponentsEditorObservable(componentFunctions:[ComponentFunction()]))
    }
}
