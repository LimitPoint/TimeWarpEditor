![TimeWarp](http://www.limit-point.com/assets/images/TimeWarpEditor.jpg)
# TimeWarpEditor
## Extension of TimeWarp

The TimeWarp method for variably speeding up or slowing down video over the whole timeline is generalized to any number of editable subintervals of time.

Learn how TimeWarp can be adapted to variably time scale one or more portions of a video from our [in-depth blog post](https://www.limit-point.com/blog/2022/time-warp-editor).

The [TimeWarp] project generalized the [Scaling Video Files] project from constant time scaling to variable time scaling over the whole video timeline by introducing time scale functions. But it is sometimes desirable to speed up or slow down only portions of the video. This project generalizes TimeWarp for variably scaling video on any collection of subintervals of the whole video timeline.

TimeWarpEditor extends the method of TimeWarp so that different time scaling can be applied to any number of subintervals of the whole timeline, by associating each time scale function with a range. Use the new `ComponentsEditor` for defining a series of different time scaling functions on a collection of disjoint ranges of the whole timeline.

[TimeWarp]: http://www.limit-point.com/blog/2022/time-warp/
[Scaling Video Files]: http://www.limit-point.com/blog/2022/scale-video/
