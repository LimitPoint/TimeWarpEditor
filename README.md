![TimeWarp](http://www.limit-point.com/assets/images/TimeWarpEditor.jpg)
# TimeWarpEditor

Discover how TimeWarp can be adapted to variably time scale one or more portions of a video.

The TimeWarp method for variably speeding up or slowing down video over the whole timeline is generalized to any number of editable subintervals of time.

Learn more about TimeWarpEditor from our [in-depth blog post](https://www.limit-point.com/blog/2022/time-warp-editor).

## Extension of TimeWarp

The [TimeWarp] project generalized the [Scaling Video Files] project from constant time scaling to variable time scaling over the whole video timeline by introducing time scale functions. But it is sometimes desirable to speed up or slow down only portions of the video. This project generalizes TimeWarp for variably scaling video on any collection of subintervals of the whole video timeline.

TimeWarpEditor extends the method of TimeWarp so that different time scaling can be applied to any number of subintervals of the whole timeline, by associating each time scale function with a range. Use the new `ComponentsEditor` for defining a series of different time scaling functions on a collection of disjoint ranges of the whole timeline. These range based time scale functions are referred to as *component functions*, with a new struct named `ComponentFunction`. 

The [TimeWarp] and [Scaling Video Files] discussions delve into the [AVFoundation], [vDSP] and [Quadrature] (numerical [integration]) techniques shared by this project.

## Time Scaling As Integration

TimeWarp implements a method that variably scales video and audio in the time domain. This means that the time intervals between video and audio samples are variably scaled along the timeline of the video according to time scaling factors that are functions of time. That contrasts with ScaleVideo in which the video was uniformly scaled by a single scaling factor. 

In [TimeWarp] the *instantaneous scaling function* was defined:

Variable time scaling is interpreted as a function on the unit interval [0,1], called a *unit function*, that specifies the instantaneous time scale factor at each time in the video, with video time mapped to the unit interval with division by its duration `D`. It will be referred to as the instantaneous time scale function. The values `v` of the instantaneous time scale function will contract or expand [infinitesimal] time intervals `dt` variably across the duration of the video as `v` * `dt`.

In this way the absolute time scale factor at any particular time `t` is the sum of all infinitesimal time scaling up to that time, or the [definite integral] of the instantaneous scaling function from `0` to `t/D`, where `D` is the duration of the video. A corollary of that is the duration of the scaled video is the original duration `D` times the integral of the instantaneous time scaling function over the whole unit interval [0,1]. That's how the estimated time of the scaled video is displayed in the user interface. 

This idea is extended in TimeWarpEditor where time scaling is now performed as piecewise integration of a series of component functions, each defined on its own range in the video timeline. 

Refer to the [mathematical justification] in TimeWarp for more discussion on how time scaling as integration works. Numerical integration, or [Quadrature], is used to calculate the integrals of the built-in time scale functions.

**Caveat:** For technical reasons a scaling function s(t) = ∫ v(t) dt, the integral of an instantaneous scaling function v(t), must keep time ordered properly: it should not reverse the order of time. If two times t<sub>a</sub> and t<sub>b</sub> are ordered as:

t<sub>a</sub> < t<sub>b</sub> 

Then it must be true that their scaled times are ordered the same:

t<sub>a</sub> * s(t<sub>a</sub>) < t<sub>b</sub> * s(t<sub>b</sub>)

One way to ensure that is for v(t) to always be positive so that s(t) = ∫ v(t) dt is always increasing. 

## TimeWarpEditor: Multiple Component Functions

In TimeWarpEditor one or more time scaling functions can be defined on disjoint subintervals of the whole timeline, using the new `ComponentsEditor`. Each subinterval is a [ClosedRange] contained in the unit interval [0,1]. These time scale functions are referred to as *component functions*.

To manage multiple component functions a new type has been defined, a struct named `ComponentFunction`, with a `range` field for specifying the subinterval of the unit interval over which it is defined.

```swift
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
```

Every `ComponentFunction` has a type `TimeWarpFunctionType`, extending the types in the [TimeWarp] project with some new built-in time scaling functions, like `smoothstep`, and a new option to flip any non-symmetrical time scaling function along the time domain. A flipped version `m(t)` of a unit function `f(t)` is defined as `m(t) = f(1-t)`. 

```swift
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
```

[TimeWarp]: http://www.limit-point.com/blog/2022/time-warp/
[ScaleVideo]: http://www.limit-point.com/blog/2022/time-warp/#scale-video
[ScaleVideoObservable]: http://www.limit-point.com/blog/2022/time-warp/#scale-video-observable
[Scaling Video Files]: http://www.limit-point.com/blog/2022/scale-video/
[mathematical justification]: http://www.limit-point.com/blog/2022/time-warp/#mathematical-justification
[built-in time scale functions]: http://www.limit-point.com/blog/2022/time-warp/#built-in-time-scale-functions
[Accelerate]: https://developer.apple.com/documentation/accelerate
[Quadrature]: https://developer.apple.com/documentation/accelerate/quadrature-smu
[infinitesimal]: https://en.wikipedia.org/wiki/Infinitesimal
[definite integral]: https://en.wikipedia.org/wiki/Integral
[antiderivative]: https://en.wikipedia.org/wiki/Antiderivative
[derivative]: https://en.wikipedia.org/wiki/Derivative
[definite integration]: https://developer.apple.com/documentation/accelerate/quadrature
[AVFoundation]: https://developer.apple.com/documentation/avfoundation/
[vDSP]: https://developer.apple.com/documentation/accelerate/vdsp
[quadrature]: https://developer.apple.com/documentation/accelerate/quadrature
[integration]: https://en.wikipedia.org/wiki/Integral
[Change of Variables]: https://en.wikipedia.org/wiki/Integration_by_substitution
[piecewise]: https://en.wikipedia.org/wiki/Piecewise
[ClosedRange]: https://developer.apple.com/documentation/swift/closedrange
[piecewise function]: https://www.mathsisfun.com/sets/functions-piecewise.html
[PlotAudio]: http://www.limit-point.com/blog/2022/plot-audio/

