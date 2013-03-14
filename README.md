REQUIRES NetLogo 5
http://ccl.northwestern.edu/netlogo/

## WHAT IS IT? 

This program attempts to model rubbernecking behavior of vehicles in freeway traffic.
Specifically, it models freeway capacity reduction: Freeway capacity is defined as the
maximum hourly rate at which persons or vehicles can reasonably transverse a point or
uniform section of a lane or roadway during a given time period. This capacity reduction
is a decrease in the maximum number of vehicles able to pass by a given section of
roadway. While maximum possible traffic flow will not change, the actual rate of vehicles
passing the specific section of freeway might be reduced due to rubbernecking. The speed
limit is set to 55 mph. The vertical yellow line toward the end of the road is the
“checkpoint” line that counts cars as they go by. The red, yellow, orange squares at the
middle top are the “distractor” – that is, the event in the median that is causing the
rubbernecking behavior. Additionally, you will notice that cars turn red when
rubbernecking.

## HOW IT WORKS

Each car on the road has a hierachy of behaviors. At each tick of the model, each car runs
its behavior loop (the drive procedure). The behaviors follow: Can I see the distractor?
Yes: potentially rubberneck (based on probability distribution and car in front of me). Am
I in traffic, i.e. stuck behind slower car(s)? Yes, in traffic: follow car in front of me,
decelerate potentially merge left or right Otherwise (not in traffic): Am I rubbernecking?
(not in traffic, but rubbernecking). Then do nothing extra. Otherwise (not in traffic, not
rubbernecking), accelerate and drive forward

## HOW TO USE IT

- Setup Button: Draws the environment and the cars, distributes the preferred speeds, etc.
- Drive Button: Initiates the behavior-loop of each car indefinitely.

### Setup parameters 

- [num-cars]: The number of cars with which to initially populate the road. This is capped
at 55 because going any higher makes it impossible to place all the cars. (default: 50)
- [acc]: Percentage of current speed by which cars increase speed when accelerating
(default: .10)
- [dec]: Percentage of current speed by which cars decrease speed when accelerating
(default: .10)
- [min-percent]: Each agent’s minimum driving speed is calculated by taking a percentage
(min-percent) of the agent’s preferred speed. (default: .60)

### Testing parameters

The model works by comparing two different conditions (a, b).

- [split-hours]: Each condition runs for split-hours number of hours. (default: 20) Each
agent has a 90-degrees cone of vision that originates -75 degrees from the car’s heading
(90 degrees, driving east). This cone of vision is sensitive to seeing the distractor in
the median.
- [vision-distance-a]: How far can the cars see in condition a?
- [vision-distance-b]: How far can the cars see in condition b? 
- [prob-boost]: Cars check if the cars in front of them are rubbernecking. If they are,
this increases the chance that the car will rubberneck by prob-boost. i.e. in this case
chance to rubberneck = prob. of rubbernecking + prob-boost.
- [merge-threshold]: Probability threshold above which cars will attempt to merge lanes.
- [dist-sd]: standard deviation of probability of rubbernecking distribution
- [dist-mean]: mean of probability of rubbernecking distribution
- [ticks-per-hour]: number of ticks equal to one hour

Steps to Running: 1. choose parameters; crucially: vision-distance-a, vision-distance-b,
split-hours vision-distance-a should be 0 and vision-distance be should be > 0 if you’re
comparing free-flow capacity (condition a) to rubbernecking capacity (condition b). click
setup click drive after (split-hours * 2) number of hours go by, you will see the output
in the command center.

## THINGS TO NOTICE
The output in the command center will produce: Capacity reduction: 1 - (max capacity in condition b / max capacity in condition a) That is, the percent capacity reduction caused by rubbernecking.

## THINGS TO TRY
- Try modifying any of the parameters (esp. vision-distance-b compared to free-flow) in order to see how the capacity reduction changes as a result.
- Try modifying the distribution parameters and see if different behaviors emerge.
- Try re-running with new setup (i.e. different distributions of preferred speed, prob. of rubbernecking, etc.) and see how the results differ.
