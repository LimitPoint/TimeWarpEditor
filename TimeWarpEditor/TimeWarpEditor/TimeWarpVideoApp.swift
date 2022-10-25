//
//  TimeWarpVideoApp.swift
//  Shared
//
//  Created by Joseph Pagliaro on 3/13/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import Combine

@main
struct TimeWarpVideoApp: App {
    
    var timeWarpVideoObservable:TimeWarpVideoObservable
    var componentsEditorObservable:ComponentsEditorObservable
    var components = [ComponentFunction()]
    
    init() {

        PrintTimeWarpFunctionTypes()
        
        print(TimeWarpFunctionType.allUnFlipped())

#if os(iOS)
        let center = UNUserNotificationCenter.current()
        
        let options: UNAuthorizationOptions = [.alert, .sound];
        center.requestAuthorization(options: options) { (granted, error) in
            if !granted {
            }
            else {
            }
        }
#endif
        
        /*
            Read any saved component functions - these will be validated by ComponentsEditorObservable in TimeWarpVideoAppView's init.
         */
        if let decodedComponents = DecodeComponentsFromUserDefaults(key: kTimeWarpEditorComponentFunctionsKey) {
            components = decodedComponents
        }
        
        timeWarpVideoObservable = TimeWarpVideoObservable()
        componentsEditorObservable = ComponentsEditorObservable(componentFunctions: components)
        timeWarpVideoObservable.validatedComponentFunctions = componentsEditorObservable.validatedComponents()
    }
    
    var body: some Scene {
        WindowGroup {
            TimeWarpVideoView(timeWarpVideoObservable: timeWarpVideoObservable, componentsEditorObservable: componentsEditorObservable)
        }
    }
}
