//
//  TimeWarpingPathViewObservable.swift
//  ComponentsEditor
//
//  Created by Joseph Pagliaro on 7/12/22.
//

import Foundation
import SwiftUI
import Combine

let kTimeWarpingPathDimension:Double = 300
let kTimeWarpingPathSubdivisions:Int = 2000

class TimeWarpingPathViewObservable : ObservableObject {
    
    @Published var componentFunctions:[ComponentFunction]
    @Published var indicatorTime:Double
    var indicatorAtZero:Bool
    
    @Published var componentPaths:[ComponentPath] = [] //[ComponentPath(path:Path())]
    @Published var selectedComponentFunctions = Set<UUID>()
    @Published var allComponentsPath = Path()
    @Published var fitPathInView:Bool
    var timeWarpingPathSize:CGSize = CGSize(width: kTimeWarpingPathDimension, height: kTimeWarpingPathDimension)//.zero
    var maximum_y:Double = 0
    var minimum_y:Double = 0
    var componentPathsRanges:[ClosedRange<Double>] = []
    
    var componentPathSelectionHandler:((Set<UUID>)->())?
    
    var cancelBag = Set<AnyCancellable>()
    
    init(componentFunctions:[ComponentFunction] = [ComponentFunction()], indicatorTime:Double = 0, indicatorAtZero:Bool, fitPathInView:Bool) {
        
        self.componentFunctions = componentFunctions
        self.indicatorTime = indicatorTime
        self.indicatorAtZero = indicatorAtZero
        self.fitPathInView = fitPathInView
        
        updatePath()
        
        $componentFunctions.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $indicatorTime.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $fitPathInView.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
        
        $selectedComponentFunctions.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePath()
            }
        }
        .store(in: &cancelBag)
    }
    
    func tapped(_ location:CGPoint) {
        if let componentPathSelectionHandler = self.componentPathSelectionHandler {
            
            if componentPathsRanges.count > 0 {
                for i in 0...componentPathsRanges.count-1 {
                    let range = componentPathsRanges[i]
                    if componentPaths[i].isSelectable, range.contains(location.x) {
                        let id = componentPaths[i].id
                        if selectedComponentFunctions.contains(id) {
                            selectedComponentFunctions.remove(id)
                        }
                        else {
                            selectedComponentFunctions.update(with: id)
                        }
                        
                        componentPathSelectionHandler(selectedComponentFunctions)
                    }
                }
            }
        }
    }
        
    func updatePath() {
        (componentPaths, minimum_y, maximum_y, allComponentsPath, componentPathsRanges) = path(a: 0, b: 1, indicatorTime:indicatorTime, indicatorAtZero: indicatorAtZero, subdivisions: kTimeWarpingPathSubdivisions, frameSize: timeWarpingPathSize, fitPathInView: fitPathInView, componentFunctions:componentFunctions)
    }
}
