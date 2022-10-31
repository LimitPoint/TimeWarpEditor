//
//  UnitFunctions.swift
//  TimeWarpEditor
//
//  Created by Joseph Pagliaro on 4/29/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//

import SwiftUI
import Foundation
import Accelerate
import AVFoundation

let kComponentFactorMax:Double = 4

enum TimeWarpFunctionType: String, Codable, CaseIterable, Identifiable {
    case doubleSmoothstep = "Double Smooth Step"
    case smoothstep = "Smooth Step"
    case smoothstepFlipped = "Smooth Step Flipped"
    case triangle = "Triangle"
    case cosine = "Cosine"
    case cosineFlipped = "Cosine Flipped"
    case sine = "Sine"
    case sineFlipped = "Sine Flipped"
    case taperedCosine = "Tapered Cosine"
    case taperedCosineFlipped = "Tapered Cosine Flipped"
    case taperedSine = "Tapered Sine"
    case taperedSineFlipped = "Tapered Sine Flipped"
    case constant = "Constant"
    case power = "Power"
    case power_flipped = "Power Flipped"
    case constantCompliment = "Constant Compliment"
    var id: Self { self }
}

extension TimeWarpFunctionType {
    func flippedType() -> TimeWarpFunctionType? {
        return TimeWarpFunctionType(rawValue: self.rawValue + " Flipped")
    }
    
    func unflippedType() -> TimeWarpFunctionType {
        let rawValue = self.rawValue.replacingOccurrences(of: " Flipped", with: "")
        return TimeWarpFunctionType(rawValue:rawValue) ?? .doubleSmoothstep
    }
    
    func isFlipped() -> Bool {
        self.rawValue.hasSuffix(" Flipped")
    }
    
    static func allUnFlipped() -> [TimeWarpFunctionType] {
        return TimeWarpFunctionType.allCases.filter { type in
            type.isFlipped() == false
        }
    }
}

func PrintTimeWarpFunctionTypes() {
    for type in TimeWarpFunctionType.allCases {
        print("Type : \(type.rawValue)")
        if let timeWarpFunctionType = type.flippedType() {
            print("Flipped version of \(type.rawValue) = \(timeWarpFunctionType.rawValue)")
        }
        else {
            print("\(type.rawValue) has no flipped version.")
        }
    }
}

func TimeWarpingFunction(timeWarpFunctionType: TimeWarpFunctionType, factor: Double, modifier:Double) -> ((Double) -> Double) {
    
    var timeWarpingFunction:(Double)->Double
    
    switch timeWarpFunctionType {
        case .doubleSmoothstep:
            let c = 1/4.0
            let w = c * modifier
            timeWarpingFunction = {t in double_smoothstep(t, from: 1, to: factor, range: c-w...c+w) }
        case .smoothstep:
            let c = 1/2.0
            let w = c * modifier
            timeWarpingFunction = {t in smoothstep(t, from: 1, to: factor, range: c-w...c+w) }
        case .smoothstepFlipped:
            let c = 1/2.0
            let w = c * modifier
            timeWarpingFunction = {t in smoothstep_flipped(t, from: factor, to: 1, range: c-w...c+w) }
        case .triangle:
            let c = 1/2.0
            let w = c * modifier
            timeWarpingFunction = {t in triangle(t, from: 1, to: factor, range: c-w...c+w) }
        case .cosine:
            timeWarpingFunction = {t in cosine(t, factor: factor, modifier: modifier) }
        case .cosineFlipped:
            timeWarpingFunction = {t in cosine_flipped(t, factor: factor, modifier: modifier) }
        case .sine:
            timeWarpingFunction = {t in sine(t, factor: factor, modifier: modifier) }
        case .sineFlipped:
            timeWarpingFunction = {t in sine_flipped(t, factor: factor, modifier: modifier) }
        case .taperedCosine:
            timeWarpingFunction = {t in tapered_cosine(t, factor: factor, modifier: modifier) }
        case .taperedCosineFlipped:
            timeWarpingFunction = {t in tapered_cosine_flipped(t, factor: factor, modifier: modifier) }
        case .taperedSine:
            timeWarpingFunction = {t in tapered_sine(t, factor: factor, modifier: modifier) }
        case .taperedSineFlipped:
            timeWarpingFunction = {t in tapered_sine_flipped(t, factor: factor, modifier: modifier) }
        case .constant:
            timeWarpingFunction = {t in constant(t, factor: factor)}
        case .constantCompliment:
            timeWarpingFunction = {t in constant(t, factor: factor)}
        case .power:
            timeWarpingFunction = {t in power(t, factor: factor, modifier: modifier) }
        case .power_flipped:
            timeWarpingFunction = {t in power_flipped(t, factor: factor, modifier: modifier) }
    }
    
    return timeWarpingFunction
}

/*
 Functions for mapping betwen frame count and unit interval.
 */
func frameCountForUnitIntervalValue(_ value:Double, videoFrameCount:Double) -> Double {
    return 1.0 + value * Double(videoFrameCount - 1)
}

func unitIntervalValueForFrameCount(_ value:Double, videoFrameCount:Double) -> Double {
    return (value - 1.0) / (Double(videoFrameCount - 1))
}

func frameCountRangeForRange(range:ClosedRange<Double>, videoFrameCount:Double) -> ClosedRange<Double> {
    return frameCountForUnitIntervalValue(range.lowerBound, videoFrameCount:videoFrameCount)...frameCountForUnitIntervalValue(range.upperBound, videoFrameCount:videoFrameCount)
}

func rangeForFrameCountRange(frameCountRange:ClosedRange<Double>, videoFrameCount:Double) -> ClosedRange<Double> {
    return unitIntervalValueForFrameCount(frameCountRange.lowerBound, videoFrameCount:videoFrameCount)...unitIntervalValueForFrameCount(frameCountRange.upperBound, videoFrameCount:videoFrameCount)
}

/*
 Functions defined on unit interval [0,1].
*/

// unitmap and mapunit are inverses
// map [x0,y0] to [0,1]
func unitmap(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x - x0)/(x1 - x0)
}

func unitmap(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return unitmap(r.lowerBound, r.upperBound, x)
}

// map [0,1] to [x0,x1] 
func mapunit(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return mapunit(r.lowerBound, r.upperBound, x)
}

func mapunit(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return (x1 - x0) * x + x0
}

// flips function on [0,1]
func unitflip(_ x:Double) -> Double {
    return 1 - x
}

// MARK: Unit Functions

func constant(_ k:Double) -> Double {
    return k
}

func line(_ x1:Double, _ y1:Double, _ x2:Double, _ y2:Double, x:Double) -> Double {
    return y1 + (x - x1) * (y2 - y1) / (x2 - x1)
}

func smoothstep(_ x:Double) -> Double {
    return -2 * pow(x, 3) + 3 * pow(x, 2)
}

func smoothstep_flip(_ x:Double) -> Double {
    return smoothstep(unitflip(x)) 
}

func smoothstep_on(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return smoothstep(unitmap(x0, x1, x)) 
}

func smoothstep_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitmap(r, x)) 
}

func smoothstep_flip_on(_ x0:Double, _ x1:Double, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(x0, x1, x)))
}

func smoothstep_flip_on(_ r:ClosedRange<Double>, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(r, x)))
}

func smoothstep_centered_on(_ c:Double, _ w:Double, _ x:Double) -> Double {
    return smoothstep(unitmap(c-w, c+w, x)) 
}

func smoothstep_flip_centered_on(_ c:Double, _ w:Double, _ x:Double) -> Double {
    return smoothstep(unitflip(unitmap(c-w, c+w, x)))
}

// MARK: TimeWarping functions to integrate and plot

func smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.25...0.75) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double = 0
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = mapunit(from, to, smoothstep_on(r2, t))
    }
    else if r3.contains(t) {
        value = constant(to)
    }
    
    return value
}

func smoothstep_flipped(_ t:Double, from:Double = 2, to:Double = 1, range:ClosedRange<Double> = 0.25...0.75) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double = 0
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = mapunit(to, from, smoothstep_flip_on(r2, t)) 
    }
    else if r3.contains(t) {
        value = constant(to)
    }
    
    return value
}
    
func double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 0.5 else {
        return 0
    }
    
    var value:Double = 0
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0-range.upperBound
    let r4 = 1.0-range.upperBound...1.0-range.lowerBound
    let r5 = 1.0-range.lowerBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = mapunit(from, to, smoothstep_on(r2, t))
    }
    else if r3.contains(t) {
        value = constant(to)
    }
    else if r4.contains(t) {
        value = mapunit(from, to, smoothstep_flip_on(r4, t))
    }
    else if r5.contains(t) {
        value = constant(from)
    }
    
    return value
}

func triangle(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.8) -> Double {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double = 0
    
    let center = (range.lowerBound + range.upperBound) / 2.0
    
    let r1 = 0...range.lowerBound
    let r2 = range.lowerBound...center
    let r3 = center...range.upperBound
    let r4 = range.upperBound...1.0
    
    if r1.contains(t) {
        value = constant(from)
    }
    else if r2.contains(t) {
        value = line(range.lowerBound, from, center, to, x: t)
    }
    else if r3.contains(t) {
        value = line(range.upperBound, from, center, to, x: t)
    }
    else if r4.contains(t) {
        value = constant(from)
    }
    
    return value
}

func cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * (cos(12 * modifier * .pi * t) + 1) + (factor / 2)
}

func cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * (cos(12 * modifier * .pi * unitflip(t)) + 1) + (factor / 2)
}

func sine(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * (sin(12 * modifier * .pi * t) + 1) + (factor / 2)
}

func sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    factor * (sin(12 * modifier * .pi * unitflip(t)) + 1) + (factor / 2)
}

func tapered_cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (cosine(t, factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, t)
}

func tapered_cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (cosine(unitflip(t), factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, unitflip(t))
}

func tapered_sine(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (sine(t, factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, t)
}

func tapered_sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    1 + (sine(unitflip(t), factor:factor, modifier:modifier) - 1) * smoothstep_on(0, 1, unitflip(t))
}

func constant(_ t:Double, factor:Double) -> Double {
    return factor
}

func power(_ t:Double, factor:Double, modifier:Double) -> Double {
    return 2 * modifier * pow(t, factor) + (modifier / 2)
}

func power_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return 2 * modifier * pow(unitflip(t), factor) + (modifier / 2)
}

// MARK: Integration

let quadrature = Quadrature(integrator: Quadrature.Integrator.nonAdaptive, absoluteTolerance: 1.0e-8, relativeTolerance: 1.0e-2)

func integrate(_ t:Double, integrand:(Double)->Double) -> Double? {
    
    var resultValue:Double?
    
    let result = quadrature.integrate(over: 0...t, integrand: { t in
        integrand(t)
    })
    
    do {
        try resultValue =  result.get().integralResult
    }
    catch {
        print("integrate error")
    }
    
    return resultValue
}

func integrate(_ r:ClosedRange<Double>, integrand:(Double)->Double) -> Double? {
    
    var resultValue:Double?
    
    let result = quadrature.integrate(over: r, integrand: { t in
        integrand(t)
    })
    
    do {
        try resultValue =  result.get().integralResult
    }
    catch {
        print("integrate error")
    }
    
    return resultValue
}

func integrate_double_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.4) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 0.5 else {
        return nil
    }
        
    var value:Double?
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0-range.upperBound
    let r4 = 1.0-range.upperBound...1.0-range.lowerBound
    let r5 = 1.0-range.lowerBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        mapunit(from, to, smoothstep_on(r2, t))
    }) else {
        return nil
    }
    
    guard let value3 = integrate(r3, integrand: { t in
        constant(to)
    }) else {
        return nil
    }
    
    guard let value4 = integrate(r4, integrand: { t in
        mapunit(from, to, smoothstep_flip_on(r4, t))
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            mapunit(from, to, smoothstep_on(r2, t))
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            constant(to)
        }) {
            value = value1 + value2 + value3
        }
    }
    else if r4.contains(t) {
        if let value4 = integrate(r4.lowerBound...t, integrand: { t in
            mapunit(from, to, smoothstep_flip_on(r4, t))
        }) {
            value = value1 + value2 + value3 + value4
        }
    }
    else if r5.contains(t) {
        if let value5 = integrate(r5.lowerBound...t, integrand: { t in
            constant(from)
        }) {
            value = value1 + value2 + value3 + value4 + value5
        }
    }
    
    return value
}

func integrate_smoothstep(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.25...0.75) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return nil
    }
    
    var value:Double?
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        mapunit(from, to, smoothstep_on(r2, t))
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            mapunit(from, to, smoothstep_on(r2, t))
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            constant(to)
        }) {
            value = value1 + value2 + value3
        }
    }
    
    return value
}

func integrate_smoothstep_flipped(_ t:Double, from:Double = 2, to:Double = 1, range:ClosedRange<Double> = 0.25...0.75) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return nil
    }
    
    var value:Double?
    
    let r1 = 0...range.lowerBound
    let r2 = range
    let r3 = range.upperBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        mapunit(to, from, smoothstep_flip_on(r2, t))
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            mapunit(to, from, smoothstep_flip_on(r2, t))
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            constant(to)
        }) {
            value = value1 + value2 + value3
        }
    }
    
    return value
}

func integrate_triangle(_ t:Double, from:Double = 1, to:Double = 2, range:ClosedRange<Double> = 0.2...0.8) -> Double? {
    
    guard from > 0, to > 0, range.lowerBound >= 0, range.upperBound <= 1 else {
        return 0
    }
    
    var value:Double?
    
    let center = (range.lowerBound + range.upperBound) / 2.0
    
    let r1 = 0...range.lowerBound
    let r2 = range.lowerBound...center
    let r3 = center...range.upperBound
    let r4 = range.upperBound...1.0
    
    guard let value1 = integrate(r1, integrand: { t in
        constant(from)
    }) else {
        return nil
    }
    
    guard let value2 = integrate(r2, integrand: { t in
        line(range.lowerBound, from, center, to, x: t)
    }) else {
        return nil
    }
    
    guard let value3 = integrate(r3, integrand: { t in
        line(range.upperBound, from, center, to, x: t)
    }) else {
        return nil
    }
    
    if r1.contains(t) {
        value = integrate(r1.lowerBound...t, integrand: { t in
            constant(from)
        })
    }
    else if r2.contains(t) {
        if let value2 = integrate(r2.lowerBound...t, integrand: { t in
            line(range.lowerBound, from, center, to, x: t)
        }) {
            value = value1 + value2
        }
    }
    else if r3.contains(t) {
        if let value3 = integrate(r3.lowerBound...t, integrand: { t in
            line(range.upperBound, from, center, to, x: t)
        }) {
            value = value1 + value2 + value3
        }
    }
    else if r4.contains(t) {
        if let value4 = integrate(r4.lowerBound...t, integrand: { t in
            constant(from)
        }) {
            value = value1 + value2 + value3 + value4
        }
    }
    
    return value
}

// MARK: Plotting
func plot_on(_ N:Int, _ x0:Double, _ x1:Double, function:(Double) -> Double) -> [Double] {
    var result:[Double] = []
    let delta = 1.0 / Double(N)
    let lower = Int((x0 / delta).rounded(FloatingPointRoundingRule.up))
    let upper = Int((x1 / delta).rounded(FloatingPointRoundingRule.down))
    if upper >= lower {
        result = (lower...upper).map { i in
            function(Double(i)/Double(N))
        }
    }
    return result
}

func plot_centered_on(_ N:Int, _ c:Double, _ w:Double, function:(Double) -> Double) -> [Double] {
    return plot_on(N, c-w, c+w, function: function)
}

/*
 Input:
    function : function to plot
    [a,b]: sampling range
    subdivisions: number of sample points in range
 
    frameSize: used to scale plot to fit inside, also using the minimum and maximum values of the sample points
    fitPathInView: option to preserve the aspect ratio of the plot (false) or stretch to fit (true)
 
    time: the time to draw indicator
    indicatorAtZero: option to draw indicator at time 0
    
 
 Output:
    A 3-tuple consisting of the Path and its minimum and maximum values
 */
func path(a:Double, b:Double, indicatorTime:Double, indicatorAtZero:Bool = true, subdivisions:Int, frameSize:CGSize, fitPathInView:Bool, componentFunctions:[ComponentFunction]) -> (componentPaths:[ComponentPath], minimum_y:Double, maximum_y:Double, allComponentsPath:Path, componentPathsRanges:[ClosedRange<Double>]) {

    let function = {t in plotComponents(t, components: componentFunctions)}
    
    guard subdivisions > 0 else {
        return ([], 0, 0, Path(), [])
    }
    
    var plot_x:[Double] = []
    var plot_y:[Double] = []
    
    let values = plot_on(subdivisions, a, b, function: function)
    
    var minimum_y:Double = values[0]
    var maximum_y:Double = values[0]
    
    let minimum_x:Double = a
    let maximum_x:Double = b
    
    let N = values.count-1
    
    for i in 0...N {
        
        let x = a + (Double(i) * ((b - a) / Double(N)))
        let y = values[i]
        
        let value = y
        if value < minimum_y {
            minimum_y = value
        }
        if value > maximum_y {
            maximum_y = value
        }
        
        plot_x.append(x)
        plot_y.append(value)
    }
    
    let frameRect = CGRect(x: 0, y: 0, width: frameSize.width, height: frameSize.height)
    
    var plotRect = frameRect
    if fitPathInView == false {
            // center a rectangle for plotting in the view frame rectangle
        plotRect = AVMakeRect(aspectRatio: CGSize(width: (maximum_x - minimum_x), height: (maximum_y - minimum_y)), insideRect: frameRect)
    }
    
    let x0 = plotRect.origin.x
    let y0 = plotRect.origin.y
    let W = plotRect.width
    let H = plotRect.height
    
    func tx(_ x:Double) -> Double {
        if maximum_x == minimum_x {
            return x0 + W
        }
        return (x0 + W * ((x - minimum_x) / (maximum_x - minimum_x)))
    }
    
    func ty(_ y:Double) -> Double {
        if maximum_y == minimum_y {
            return frameSize.height - (y0 + H)
        }
        return frameSize.height - (y0 + H * ((y - minimum_y) / (maximum_y - minimum_y))) // subtract from frameSize.height to flip coordinates
    }
    
        // map points into plotRect using linear interpolation
    plot_x = plot_x.map( { x in
        tx(x)
    })
    
    plot_y = plot_y.map( { y in
        ty(y)
    })
    
    let allComponentsPath = Path { path in
        
        path.move(to: CGPoint(x: plot_x[0], y: plot_y[0]))
        
        for i in 1...N {
            let x = plot_x[i]
            let y = plot_y[i]
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        if indicatorTime > 0  || (indicatorTime == 0 && indicatorAtZero) {
            let t = a + indicatorTime * (b - a)
            let xTime = tx(t)
            let yTime = ty(function(t))
            path.addEllipse(in: CGRect(x: xTime-3, y: yTime-3, width: 6, height: 6))
        }
        
    }
    
    var componentPaths:[ComponentPath] = []
    var componentPathsRanges:[ClosedRange<Double>] = []
    
    for componentFunction in componentFunctions {
        
        var path = Path()
        var count = 0
        
        let lowerBound = tx(componentFunction.range.lowerBound)
        let upperBound = tx(componentFunction.range.upperBound)
        let range = lowerBound...upperBound
        
        for i in 0...N {
            let x = plot_x[i]
            let y = plot_y[i]
            
            if range.contains(x) {
                count += 1
                
                if count == 1 {
                    path.move(to: CGPoint(x: x, y: y))
                }
                else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        
        componentPathsRanges.append(range)
        componentPaths.append(ComponentPath(path:path, isSelectable: (componentFunction.timeWarpFunctionType != .constantCompliment), id:componentFunction.id))
    }
    
    return (componentPaths, minimum_y, maximum_y, allComponentsPath, componentPathsRanges)
}

// MARK: Piecewise Functions

// MARK: Range Helpers
/*
    rangesAreUnitSubintervals - ranges are subintervals of unit interval
    rangesHaveNonZeroLength - check that ranges are not points
    rangesOverlap - checks if ranges overlap BUT returns FALSE if overlap at endpoints only 
    sortRanges - sort ranges by their start date
 */

    // check all ranges in unit interval [0,1]
func rangesAreUnitSubintervals(_ ranges:[ClosedRange<Double>]) -> Bool {
    
        // lower bounds must always be less than upper bounds 
        // let x:ClosedRange<Double> = 5.0...2.1 -> ERROR
        // So we just need to check the following
    
    let lowerBounds = ranges.map { crd in
        crd.lowerBound
    }
    
    let minLowerBound = vDSP.maximum(lowerBounds)
    
    guard minLowerBound >= 0 && minLowerBound <= 1 else {
        return false
    }
    
    let upperBounds = ranges.map { crd in
        crd.upperBound
    }
    
    let maxUpperBound = vDSP.maximum(upperBounds)
    
    guard maxUpperBound >= 0 && maxUpperBound <= 1 else {
        return false
    }
    
    return true
}

func rangesHaveNonZeroLength(_ ranges:[ClosedRange<Double>]) -> Bool {
    for range in ranges {
        if range.lowerBound == range.upperBound {
            return false
        }
    }
    
    return true
}

    // Our own 'overlap' test that allows overlap at just edges, i.e. if overlap is just end endpoints we consider them NOT overlapping
func rangesOverlap(_ r1:ClosedRange<Double>, _ r2:ClosedRange<Double>) -> Bool {
    
    if r1.overlaps(r2) == false {
        return false
    }
    
    if r1.upperBound == r2.lowerBound || r1.lowerBound == r2.upperBound {
        return false
    }
    
    return true
}

    // chack all pairs but for comparing to self
func rangesOverlap(_ ranges:[ClosedRange<Double>]) -> Bool {
    for i in 0...ranges.count-1 {
        for j in 0...ranges.count-1 {
            if i != j {
                if rangesOverlap(ranges[i],ranges[j]) {
                    return true
                }
            }
        }
    }
    return false
}

func sortRanges(_ ranges:[ClosedRange<Double>]) -> [ClosedRange<Double>] {
    return ranges.sorted { r1, r2 in
        r1.lowerBound < r2.lowerBound
    }
}

func validateAndSort(_ ranges:[ClosedRange<Double>]) -> [ClosedRange<Double>]? {
    guard ranges.count > 0 else {
        print("validateAndSort Failed: no ranges")
        return nil
    }
    
    guard rangesHaveNonZeroLength(ranges) else {
        print("validateAndSort Failed: rangesHaveNonZeroLength")
        return nil
    }
    
    guard rangesAreUnitSubintervals(ranges) else {
        print("validateAndSort Failed: rangesAreUnitSubintervals")
        return nil
    }
    
    guard rangesOverlap(ranges) == false else {
        print("validateAndSort Failed: rangesOverlap")
        return nil
    }
    
    return sortRanges(ranges)
}

    // The requirement is: ranges must be non-overlapping subintervals of the unit interval, with non-zero length
    // nil is returned on error
    // Returned array may be empty
func complimentOfRanges(_ ranges:[ClosedRange<Double>]) -> [ClosedRange<Double>]? {
    
    var compliments:[ClosedRange<Double>]?
        
    guard let sorted_ranges = validateAndSort(ranges) else {
        print("validateAndSort Failed")
        return nil
    }
    
    compliments = []
    
    if sorted_ranges[0].lowerBound > 0 {
        compliments?.append(0...sorted_ranges[0].lowerBound)
    }
    
    if sorted_ranges.count > 1 {
        for i in 0...sorted_ranges.count-2 {
            if sorted_ranges[i].upperBound < sorted_ranges[i+1].lowerBound {
                compliments?.append(sorted_ranges[i].upperBound...sorted_ranges[i+1].lowerBound)
            }
        }
    }
    
    if sorted_ranges[sorted_ranges.count-1].upperBound < 1.0 {
        compliments?.append(sorted_ranges[sorted_ranges.count-1].upperBound...1.0)
    }
    
    return compliments
}

func matchFitRangetoComplimentOfRanges(range:ClosedRange<Double>, ranges:[ClosedRange<Double>]) -> ClosedRange<Double>? {
    if let complimentOfRanges = complimentOfRanges(ranges) {
        for aRange in complimentOfRanges {
            if rangesOverlap(range,aRange) {
                return aRange
            }
            else {
                return complimentOfRanges.first
            }
        }
    }
    
    return nil
}

// MARK: ComponentFunction
/*
 The factor and modifier values are for the specific unit functions defined in this file, and values that make sense should be observed. 
 Therefore a constraint has been added to the intializer
 */
struct ComponentFunction: Codable, Identifiable, CustomStringConvertible  {
    
    var range:ClosedRange<Double> = 0.0...1.0 
    var factor:Double = 1.5 // 0.1 to kComponentFactorMax
    var modifier:Double = 0.5 // 0.1 to 1
    var timeWarpFunctionType:TimeWarpFunctionType = .doubleSmoothstep
    
    var id = UUID()
    
    init() {
        
    }
    
    init(range:ClosedRange<Double>) {
        self.range = range
    }
    
    init?(range:ClosedRange<Double>, factor:Double, modifier:Double, timeWarpFunctionType: TimeWarpFunctionType) {
        
        guard range.lowerBound >= 0, range.lowerBound < 1.0, range.upperBound > 0, range.upperBound <= 1.0 else {
            return nil
        }
        
        guard factor >= 0.1, factor <= kComponentFactorMax, modifier >= 0.1, modifier <= 1 else {
            return nil
        }
        
        self.range = range
        
        self.factor = factor
        self.modifier = modifier
        self.timeWarpFunctionType = timeWarpFunctionType
    }
    
    var description: String {
        "\(range), \(factor), \(modifier), \(timeWarpFunctionType)"
    }

}

struct ComponentPath: Identifiable {
    var path:Path
    var isSelectable:Bool
    var id = UUID()
}

    // MARK: Encode/Decode Components
func EncodeComponentsToUserDefaults(key:String, componentFunctions:[ComponentFunction]?) {
    
    guard let componentFunctions = componentFunctions, let sortedComponents = sortComponentFuntions(componentFunctions) else {
        //UserDefaults.standard.set(nil, forKey: key)
        return
    }
    
    if let encodedData = try? JSONEncoder().encode(sortedComponents) {
        UserDefaults.standard.set(encodedData, forKey: key)
    }
}

func DecodeComponentsFromUserDefaults(key:String) -> [ComponentFunction]? {
    var sortedComponents:[ComponentFunction]?
    if let decodedData = UserDefaults.standard.object(forKey: key) as? Data {
        if let decodedComponents = try? JSONDecoder().decode([ComponentFunction].self, from: decodedData) {
            sortedComponents = sortComponentFuntions(decodedComponents)
        }
    }
    
    return sortedComponents
}

    // MARK: Functions on Components
func plot(componentFunction:ComponentFunction) -> (Double,Double,Double)->Double {
    switch componentFunction.timeWarpFunctionType {
        case .doubleSmoothstep:
            return plot_double_smoothstep(_:factor:modifier:)
        case .smoothstep:
            return plot_smoothstep(_:factor:modifier:)
        case .smoothstepFlipped:
            return plot_smoothstep_flipped(_:factor:modifier:)
        case .triangle:
            return plot_triangle(_:factor:modifier:)
        case .cosine:
            return plot_cosine(_:factor:modifier:)
        case .cosineFlipped:
            return plot_cosine_flipped(_:factor:modifier:)
        case .sine:
            return plot_sine(_:factor:modifier:)
        case .sineFlipped:
            return plot_sine_flipped(_:factor:modifier:)
        case .taperedCosine:
            return plot_tapered_cosine(_:factor:modifier:)
        case .taperedCosineFlipped:
            return plot_tapered_cosine_flipped(_:factor:modifier:)
        case .taperedSine:
            return plot_tapered_sine(_:factor:modifier:)
        case .taperedSineFlipped:
            return plot_tapered_sine_flipped(_:factor:modifier:)
        case .constant:
            return plot_constant(_:factor:modifier:)
        case .constantCompliment:
            return plot_constant(_:factor:modifier:)
        case .power:
            return plot_power(_:factor:modifier:)
        case .power_flipped:
            return plot_power_flipped(_:factor:modifier:)
    }
}

func plot(_ t:Double, componentFunction:ComponentFunction) -> Double {    
    return plot(componentFunction: componentFunction)(unitmap(componentFunction.range.lowerBound, componentFunction.range.upperBound, t), componentFunction.factor, componentFunction.modifier)
    
}

func integrate(_ t:Double, componentFunction:ComponentFunction) -> Double? {
    
    if let value = integrator(for:componentFunction)(unitmap(componentFunction.range.lowerBound, componentFunction.range.upperBound, t), componentFunction.factor, componentFunction.modifier) {
        return value * (componentFunction.range.upperBound - componentFunction.range.lowerBound)
    }
    
    return nil
}

func integrator(for componentFunction:ComponentFunction) -> (Double,Double,Double)->Double? {
    switch componentFunction.timeWarpFunctionType {
        case .doubleSmoothstep:
            return integrate_double_smoothstep(_:factor:modifier:)
        case .smoothstep:
            return integrate_smoothstep(_:factor:modifier:)
        case .smoothstepFlipped:
            return integrate_smoothstep_flipped(_:factor:modifier:)
        case .triangle:
            return integrate_triangle(_:factor:modifier:)
        case .cosine:
            return integrate_cosine(_:factor:modifier:)
        case .cosineFlipped:
            return integrate_cosine_flipped(_:factor:modifier:)
        case .sine:
            return integrate_sine(_:factor:modifier:)
        case .sineFlipped:
            return integrate_sine_flipped(_:factor:modifier:)
        case .taperedCosine:
            return integrate_tapered_cosine(_:factor:modifier:)
        case .taperedCosineFlipped:
            return integrate_tapered_cosine_flipped(_:factor:modifier:)
        case .taperedSine:
            return integrate_tapered_sine(_:factor:modifier:)
        case .taperedSineFlipped:
            return integrate_tapered_sine_flipped(_:factor:modifier:)
        case .constant:
            return integrate_constant(_:factor:modifier:)
        case .constantCompliment:
            return integrate_constant(_:factor:modifier:)
        case .power:
            return integrate_power(_:factor:modifier:)
        case .power_flipped:
            return integrate_power_flipped(_:factor:modifier:)
    }
}

func timeScale(componentFunction:ComponentFunction) -> Double {
    guard let timeScale = integrate(componentFunction.range.upperBound, componentFunction: componentFunction) else {
        return 0
    }
    return timeScale
}

func contains(_ t:Double, componentFunction:ComponentFunction) -> Bool {
    return componentFunction.range.contains(t)
}

func timeWarpingFunction(componentFunction:ComponentFunction) -> ((Double) -> Double) {
    return TimeWarpingFunction(timeWarpFunctionType: componentFunction.timeWarpFunctionType, factor: componentFunction.factor, modifier: componentFunction.modifier)
}

func timeWarpingFunctionPath(currentTime:Double, pathViewFrameSize:CGSize, fitPathInView:Bool, componentFunction:ComponentFunction) -> Path {
    
    if let validatedComponents = addConstantCompliments([componentFunction]) {
        return path(a: 0, b: 1, indicatorTime: currentTime, indicatorAtZero: false, subdivisions: Int(pathViewFrameSize.width), frameSize: pathViewFrameSize, fitPathInView: fitPathInView, componentFunctions: validatedComponents).allComponentsPath
    }
    
    return Path()
}

    // MARK: Plot & Integrate Components
func plotComponents(_ t:Double, components:[ComponentFunction]) -> Double {
        
    for component in components {
        if contains(t, componentFunction: component) {
            return plot(t, componentFunction: component )
        }
    }
    
    return 0
}

func integrateComponents(_ t:Double, components:[ComponentFunction]) -> Double? {
    
    var value:Double = 0
    
    for component in components {
        if contains(t, componentFunction: component) {
            if let integral = integrate(t, componentFunction: component) {
                value += integral
                return value
            }
        }
        value += timeScale(componentFunction: component)
    }
    
    return value
}


    // MARK: ComponentFunction Helpers that mimic Range Helpers
/*
    sortComponentFuntions - sort components by lower bound of the time range (makes sense since we requier them not to overlap)
    constantCompliments - compute constant function compliments of components
    addConstantCompliments - add constant function components to components
 */

// If the ranges are valid sort components by range
func sortComponentFuntions(_ components:[ComponentFunction]) -> [ComponentFunction]? {
    
    let ranges = components.map { cf in
        cf.range
    }
    
    guard let _ = validateAndSort(ranges) else {
        print("validateAndSort Failed")
        return nil
    }
    
    let sortedComponents = components.sorted { cf1, cf2 in
        cf1.range.lowerBound < cf2.range.lowerBound
    }
    
    return sortedComponents
}

// nil is returned on error
func constantCompliments(_ components:[ComponentFunction]) -> [ComponentFunction]? {
    
    let ranges = components.map { cf in
        cf.range
    }
    
    guard let complimentsOfRanges = complimentOfRanges(ranges) else {
        return nil
    }
    
    var constantCompliments:[ComponentFunction] = []
    
    // none of the items should be nil anyway, but need to use compactMap
    for range in complimentsOfRanges {
        guard let component = ComponentFunction(range: range, factor: 1, modifier: 1, timeWarpFunctionType: .constantCompliment) else {
            return nil
        }
        
        constantCompliments.append(component)
    }

    return constantCompliments
}

func addConstantCompliments(_ components:[ComponentFunction]) -> [ComponentFunction]? {
        
    guard let constantComponents = constantCompliments(components) else {
        print("constantComponents is nil - check parameters")
        return nil
    }
    
    var newComponents:[ComponentFunction] = components
    
    newComponents.append(contentsOf: constantComponents)

    return sortComponentFuntions(newComponents)
}

// redefine the existing unit functions for each of the TimeWarpFunctionType's with the same signature, so they can be referenced as a function type for plotting and integrating
// Note that the values for factor and modfier need to make sense for each. Like factor, modifer = 2,3 for `triangle` don't work
/*
 constant
 doubleSmoothstep
 triangle
 cosine
 taperedCosine
 power
 */

// MARK: Plot & Integrate Constant
func plot_constant(_ t:Double, factor:Double, modifier:Double) -> Double {
    return constant(t, factor: factor)
}

func integrate_constant(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        constant(t, factor: factor)
    })
}

// MARK: Plot & Integrate Double Smoothstep
func plot_double_smoothstep(_ t:Double, factor:Double, modifier:Double) -> Double {
    let c = 1/4.0
    let w = c * modifier
    return double_smoothstep(t, from: 1, to: factor, range: c-w...c+w)
}

func integrate_double_smoothstep(_ t:Double, factor:Double, modifier:Double) -> Double? {
    let c = 1/4.0
    let w = c * modifier
    return integrate_double_smoothstep(t, from: 1, to: factor, range: c-w...c+w)
}

    // MARK: Plot & Integrate Smoothstep
func plot_smoothstep(_ t:Double, factor:Double, modifier:Double) -> Double {
    let c = 1/2.0
    let w = c * modifier
    return smoothstep(t, from: 1, to: factor, range: c-w...c+w)
}

func integrate_smoothstep(_ t:Double, factor:Double, modifier:Double) -> Double? {
    let c = 1/2.0
    let w = c * modifier
    return integrate_smoothstep(t, from: 1, to: factor, range: c-w...c+w)
}

    // MARK: Plot & Integrate Smoothstep Flipped
func plot_smoothstep_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    let c = 1/2.0
    let w = c * modifier
    return smoothstep_flipped(t, from: factor, to: 1, range: c-w...c+w)
}

func integrate_smoothstep_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    let c = 1/2.0
    let w = c * modifier
    return integrate_smoothstep_flipped(t, from: factor, to: 1, range: c-w...c+w)
}

// MARK: Plot & Integrate Triangle
func plot_triangle(_ t:Double, factor:Double, modifier:Double) -> Double {
    let c = 1/2.0
    let w = c * modifier
    return triangle(t, from: 1, to: factor, range: c-w...c+w)
}

func integrate_triangle(_ t:Double, factor:Double, modifier:Double) -> Double? {
    let c = 1/2.0
    let w = c * modifier
    return integrate_triangle(t, from: 1, to: factor, range: c-w...c+w)
}

// MARK: Plot & Integrate Cosine
func plot_cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    return cosine(t, factor: factor, modifier: modifier)
}

func integrate_cosine(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        cosine(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Cosine Flipped
func plot_cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return cosine_flipped(t, factor: factor, modifier: modifier)
}

func integrate_cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        cosine_flipped(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Sine
func plot_sine(_ t:Double, factor:Double, modifier:Double) -> Double {
    return sine(t, factor: factor, modifier: modifier)
}

func integrate_sine(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        sine(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Sine Flipped
func plot_sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return sine_flipped(t, factor: factor, modifier: modifier)
}

func integrate_sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        sine_flipped(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Tapered Cosine
func plot_tapered_cosine(_ t:Double, factor:Double, modifier:Double) -> Double {
    return tapered_cosine(t, factor: factor, modifier: modifier)
}

func integrate_tapered_cosine(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        tapered_cosine(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Tapered Cosine Flipped
func plot_tapered_cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return tapered_cosine_flipped(t, factor: factor, modifier: modifier)
}

func integrate_tapered_cosine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        tapered_cosine_flipped(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Tapered Sine
func plot_tapered_sine(_ t:Double, factor:Double, modifier:Double) -> Double {
    return tapered_sine(t, factor: factor, modifier: modifier)
}

func integrate_tapered_sine(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        tapered_sine(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Tapered Sine Flipped
func plot_tapered_sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return tapered_sine_flipped(t, factor: factor, modifier: modifier)
}

func integrate_tapered_sine_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        tapered_sine_flipped(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Power
func plot_power(_ t:Double, factor:Double, modifier:Double) -> Double {
    return power(t, factor: factor, modifier: modifier)
}

func integrate_power(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        power(t, factor: factor, modifier: modifier)
    })
}

// MARK: Plot & Integrate Power Flipped
func plot_power_flipped(_ t:Double, factor:Double, modifier:Double) -> Double {
    return power_flipped(t, factor: factor, modifier: modifier)
}

func integrate_power_flipped(_ t:Double, factor:Double, modifier:Double) -> Double? {
    return integrate(t, integrand: { t in 
        power_flipped(t, factor: factor, modifier: modifier)
    })
}

    // MARK: Sample Components - [.constant, .triangle, .cosine, .taperedCosine, .power, .doubleSmoothstep]
/*
    let components = makeSampleComponents(factor: 1.5, modifier: 0.5)

    print("sample components = \(components)")

    EncodeComponentsToUserDefaults(key: "ComponentFunctions", componentFunctions: components)

    if let decodedComponents = DecodeComponentsFromUserDefaults(key: "ComponentFunctions") {
        print("decoded sample components = \(decodedComponents)")
    }
 */
func makeSampleComponents(factor:Double, modifier:Double) -> [ComponentFunction] {
    
    var components:[ComponentFunction] = []
    
    let d = 1.0 / 6.0
    
    let timeWarpFunctionTypes:[TimeWarpFunctionType] = [.constant, .triangle, .cosine, .taperedCosine, .power, .doubleSmoothstep]
    
    for i in 0...5 {
        let range = Double(i)*d...Double(i+1)*d
        
        if let component = ComponentFunction(range: range, factor: factor, modifier: modifier, timeWarpFunctionType: timeWarpFunctionTypes[i]) {
            components.append(component)
        }
    }
    
    return components
}
