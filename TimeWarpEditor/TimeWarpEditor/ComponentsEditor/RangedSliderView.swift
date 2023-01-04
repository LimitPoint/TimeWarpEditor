//
//  RangedSliderView.swift
//  TimeWarpEditor
//
//  Read discussion at:
//  http://www.limit-point.com/blog/2022/time-warp-editor/
//
//  Created by Joseph Pagliaro on 6/24/22.
//  Copyright © 2022 Limit Point LLC. All rights reserved.
//
// Adapted from : https://stackoverflow.com/questions/62587261/swiftui-2-handle-range-slider

import SwiftUI

let kThumbwidth:CGFloat = 10
let kThumbheight:CGFloat = 20
let kThumbcolor:Color = Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.8)

protocol RangedSliderViewDelegate: AnyObject {
    func rangedSliderEnded()
}

struct RangedSliderView: View {

    var frameCount:Int // videoFrameCount
    @Binding var frameCountRange:ClosedRange<Double>
    var displayRangeForFrameCountRange:(ClosedRange<Double>, Double)->ClosedRange<Double> // rangeForFrameCountRange
    weak var rangedSliderViewDelegate:RangedSliderViewDelegate?
    
    var body: some View {
        GeometryReader { geometry in
            sliderView(sliderSize: geometry.size)
        }
    }
    
    @ViewBuilder private func sliderView(sliderSize: CGSize) -> some View {
        let sliderViewYCenter = sliderSize.height / 2
        
        let sliderBounds = 1...frameCount
        
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(height: 4)
            ZStack {
                let sliderBoundDifference = sliderBounds.count //- 1
                let stepWidthInPixel = CGFloat(sliderSize.width) / CGFloat(sliderBoundDifference)
                
                    // Calculate Left Thumb initial position
                let leftThumbLocation: CGFloat = $frameCountRange.wrappedValue.lowerBound == Double(sliderBounds.lowerBound)
                ? 0
                : CGFloat($frameCountRange.wrappedValue.lowerBound - Double(sliderBounds.lowerBound)) * stepWidthInPixel
                
                    // Calculate right thumb initial position
                let rightThumbLocation = CGFloat($frameCountRange.wrappedValue.upperBound) * stepWidthInPixel
                
                    // Path between both handles
                lineBetweenThumbs(from: .init(x: leftThumbLocation, y: sliderViewYCenter), to: .init(x: rightThumbLocation, y: sliderViewYCenter))
                
                    // Left Thumb Handle
                let leftThumbPoint = CGPoint(x: leftThumbLocation, y: sliderViewYCenter)
                                
                thumbView(position: leftThumbPoint, displayValue: displayRangeForFrameCountRange(frameCountRange, Double(frameCount)).lowerBound, above: false)
                    .highPriorityGesture(DragGesture().onChanged({ dragValue in
                        
                        let dragLocation = dragValue.location
                        let xThumbOffset = min(max(0, dragLocation.x), sliderSize.width)
                        
                        let newValue = Double(sliderBounds.lowerBound) + Double(xThumbOffset / stepWidthInPixel)
                        
                            // Stop the range thumbs from colliding each other
                        if newValue < frameCountRange.upperBound - (kThumbwidth / stepWidthInPixel) {
                            frameCountRange = newValue...frameCountRange.upperBound
                        }
                    })
                        .onEnded({ _ in
                            rangedSliderViewDelegate?.rangedSliderEnded()
                        })
                    )
                
                    // Right Thumb Handle
                thumbView(position: CGPoint(x: rightThumbLocation, y: sliderViewYCenter), displayValue: displayRangeForFrameCountRange(frameCountRange, Double(frameCount)).upperBound, above: true)
                    .highPriorityGesture(DragGesture().onChanged({ dragValue in
                        
                        let dragLocation = dragValue.location
                        let xThumbOffset = min(max(CGFloat(leftThumbLocation), dragLocation.x), sliderSize.width)
                        
                        var newValue = Double(xThumbOffset / stepWidthInPixel) // convert back the value bound
                        newValue = min(newValue, Double(sliderBounds.upperBound))
                        
                            // Stop the range thumbs from colliding each other
                        if newValue > frameCountRange.lowerBound + (kThumbwidth / stepWidthInPixel) {
                            frameCountRange = frameCountRange.lowerBound...newValue
                        }
                    })
                        .onEnded({ _ in
                            rangedSliderViewDelegate?.rangedSliderEnded()
                        })
                    )
            }
        }
    }
    
    @ViewBuilder func lineBetweenThumbs(from: CGPoint, to: CGPoint) -> some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }.stroke(Color.red, lineWidth: 4)
    }
    
    @ViewBuilder func thumbView(position: CGPoint, displayValue: Double, above:Bool) -> some View {
        ZStack {
            Text(String(format: kRangePrecisonDisplay, displayValue))
                .font(.system(size: 10))
                .offset(y: (above ? -20 : 20))
            
            Capsule()
                .frame(width: kThumbwidth, height: kThumbheight)
                .foregroundColor(kThumbcolor)
        }
        .position(x: position.x, y: position.y)
    }
}

struct RangedSliderViewWrapper: View {
   
    @State var sliderPosition: ClosedRange<Double> = 1...100.0
    
    var body: some View {
        VStack {
            RangedSliderView(frameCount: 100, frameCountRange: $sliderPosition) { r, _ in
                r
            }
            .padding()
            Text("\(String(format: kRangePrecisonDisplay, sliderPosition.lowerBound))...\(String(format: kRangePrecisonDisplay, sliderPosition.upperBound))")
        }
        
    }
}

struct RangedSliderView_Previews: PreviewProvider {
    static var previews: some View {
        RangedSliderViewWrapper().padding()
    }
}
