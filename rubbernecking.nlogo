globals 
[
  speed-limit          ;; global speed limit of road
  under-limit          ;; num cars under speed limit
  passed               ;; num cars past checkpoint
  passed-this-hour     ;; how many cars passed the checkpoint this hour
  hour                 ;; current hour
  avg-speed            ;; the global average speed over all cars
  vision-distance      ;; current distance cars can see (to distractor)
  a-data               ;; data from condition a
  b-data               ;; data from condition b
]

breed [cars car]
patches-own
 [
   road?               ;; is this patch a road?
   fire?               ;; is this patch a distractor? (fire)
   checkpoint          ;; is this patch part of the checkpoint?
 ]
 
turtles-own
[
  mph                  ;; current speed in miles per hour.
  pref-speed           ;; the maximum speed accelerated to in free-flow traffic.
  lane                 ;; lane that the car originally occupied.
  speed                ;; current speed of the car in NetLogo terms (mph / speed-limit).
  my-leader            ;; identifier of the car in front of this car.
  in-traffic?          ;; boolean indicating if the vehicle is both not at pref-speed and behind other cars. 
  prob-neck            ;; probability of rubbernecking (from Gaussian distribution).
  necking?             ;; boolean indicating if the vehicle is rubbernecking.
  min-speed            ;; the minimum speed the driver is willing to go (min-percent * pref-speed).
  past-checkpoint?     ;; boolean indicating if the car has passed the checkpoint (yellow bar).
]

to setup
  clear-all
  set speed-limit 55
  set under-limit 0
  set passed 0
  set passed-this-hour 0
  set hour -1
  set a-data []
  set b-data [] 
  set vision-distance vision-distance-a
 
  set-default-shape cars "car"
  setup-environ

  create-cars (num-cars)
  [ 
    setup-vehicle
    set size 2
  ]
  reset-ticks
end

to setup-environ
  ask patches 
  [ 
    ;; draw grass and dirt
    set pcolor (one-of [green brown])
    
    ;; draw pavement
    if ((pycor > -6) and (pycor < 6))
    [ 
      set pcolor gray - 3
    ]
    
    ;; set road?
    if pycor = 2 or pycor = -2
    [ set road? true ]
    
    ;; dashed medians
    if (pycor = 0 and (pxcor mod 3) = 0)
    [ set pcolor white ]
    if pycor = 4 or pycor = -4
    [ set pcolor white ]

    ;; draw fire
    if (pycor >= 6) and (pxcor < 1) and (pxcor > -5)
    [ 
      set pcolor yellow 
      set fire? true
    ]
    if (pycor >= 7) and (pxcor < 0) and (pxcor > -4)
    [ set pcolor orange ]
    if (pycor >= 7) and (pxcor < -1) and (pxcor > -3)
    [ set pcolor red ]
    
    ;; set checkpoints
    if (pxcor = 50) 
    [ set checkpoint true
      set pcolor yellow ]    
  ]
end

;; code for setting up each car
to setup-vehicle
  set color 106                         ;; make cars blue  
  set mph random-normal 59.0 7.0        ;; normal distribution of mph
  if mph < 55
  [ set under-limit (under-limit + 1) ]
  set pref-speed (mph / 55)             ;; transform mph to patch-based speeds
  
  set prob-neck random-normal dist-mean dist-sd
  set past-checkpoint? false
  set min-speed (min-percent * pref-speed)
  set speed pref-speed
  set necking? false
  set in-traffic? false
  
  ;; randomly place the cars somewhere in a lane
  set lane (random 2)
  ifelse (lane = 0)
  [ setxy random-pxcor 2 ]
  [ setxy random-pxcor -2 ]
  set heading 90
  
  ;; evenly separate the cars and trucks
  loop
  [
    ifelse any? other turtles-here or 
    any? other turtles-on (patch-set 
      patch-at -1 0 
      patch-at -2 0 
      patch-at 1 0 
      patch-at 2 0) 
    [ move-to one-of (patches with [road? = true]) ]
    [ stop ]
  ]
end

;; rubbernecking behavior -- drive at min-speed
to rubberneck
  set color red
  set speed min-speed
  set heading 90
  set necking? true
  if not in-traffic?
    [ move-forward ]
end

;; behavior-based architecture: this loop is run for each agent at every tick.
to drive
  ask turtles 
    [ 
      ;;; calculating checkpoints
      if pxcor >= 50 and not past-checkpoint?
      [ set passed (passed + 1) 
        set color yellow
        set past-checkpoint? true ]
      if pxcor < 50
      [ set past-checkpoint? false ]
      
      ;;; figure out if car is in traffic
      ifelse any? other turtles in-cone 3 30
      [ set in-traffic? true ]
      [ set in-traffic? false]

      ;;; can I see the distractor? If yes, potentially rubberneck.
      set heading 15
      ifelse any? patches with [fire? = true] in-cone vision-distance 90
      [ 
        ifelse necking?
        [ rubberneck ]
        [
          ifelse member? my-leader (turtles with [necking? = true])
          [
            set prob-neck (prob-neck + prob-boost)  
            if (random-float 1.0) <= prob-neck
            [ rubberneck ]
            set prob-neck prob-neck - prob-boost
          ]
          [
            if random-float 1.0 <= prob-neck
            [ rubberneck ]
          ]
        ]       
      ]
      [ 
        set necking? false
        set color 106 
      ]
      
      ;;; am I in traffic? if yes, FOLLOW TRAFFIC (slowest car in front), decelerate.
      set heading 90
      ifelse in-traffic?
      [
        set my-leader min-one-of (other turtles in-cone 3 30) [distance myself]
        set speed [speed] of my-leader  
        decelerate dec
        
        ;;; maybe try to MERGE out of traffic (50-50 chance of trying Left, Right vs. Right, Left)
        if (random-float 1.0) > merge-threshold 
          [ 
            ifelse random 2 = 0
            [ ;; LEFT
              set heading 20 
              ifelse not any? other turtles in-cone 6 80 and member? (patch-at 1.2 4) patches with [road? = true] 
              [ 
                set color green
                move-to patch-at 1.2 4 
              ]
              [ ;; RIGHT
                set heading 160
                if not any? other turtles in-cone 6 80 and member? (patch-at 1.2 -4) patches with [road? = true] 
                [ 
                  set color green
                  move-to patch-at 1.2 -4 
                ]
              ] ;; end else
              set heading 90
            ];; end if
            [  ;; RIGHT           
              set heading 160
                ifelse not any? other turtles in-cone 6 80 and member? (patch-at 1.2 -4) patches with [road? = true] 
                [ 
                  set color green
                  move-to patch-at 1.2 -4 
                ]
                [ ;; LEFT
                  set heading 20 
                  if not any? other turtles in-cone 6 80 and member? (patch-at 1.2 4) patches with [road? = true] 
                  [ 
                    set color green
                    move-to patch-at 1.2 4 
                  ]
                ]
                set heading 90
            ] ;; end else
          ] ;; end if
      ] ;; end if
      
      ;; if I'm not in traffic and not rubbernecking, accelerate and move forward
      [ 
        if not necking?
        [
          accelerate acc
          move-forward
        ]
      ];; end else
    ] ;; end ask turtles

  tick
  
  ;;; TESTING BITS
  if ticks mod ticks-per-hour = 0
  [ 
    ifelse hour = split-hours
    [
      set vision-distance vision-distance-b
      set a-data lput passed-this-hour a-data
    ]
    [
      ifelse hour < split-hours
      [
        set a-data lput passed-this-hour a-data
      ]
      [
        ifelse hour >= (split-hours * 2)
        [
          set b-data lput passed-this-hour b-data
          print "#####   BEGIN RESULTS   #########################"
          set a-data but-first a-data
          type "reduction | free-flow capacity | sd | actual capacity | sd | under limit | dist-mean\n" 
          type (1 - (max b-data) / (max a-data)) type " | " 
          type max a-data type " | " 
          type standard-deviation a-data type " | "
          type max b-data type " | "
          type standard-deviation b-data type " | "
          type 1 - (under-limit / num-cars) type " | "
          type dist-mean type "\n"
          print "#####   END RESULTS    ##########################"
        ]
        [
          set b-data lput passed-this-hour b-data
        ] 
      ]
    ]
  ]
  
end

;;; jump forward speed number of patches
to move-forward
  ifelse speed > pref-speed
  [
    set speed pref-speed
    jump speed
  ]
  [ 
    ifelse speed < min-speed
    [ 
      set speed min-speed
      jump speed
    ]
    [jump speed ] 
  ]
end
  
to accelerate [x]
  set speed (speed + (speed * acc))
end

to decelerate [x]
  set speed (speed - (speed * dec))
end
@#$#@#$#@
GRAPHICS-WINDOW
182
10
1402
211
60
8
10.0
1
10
1
1
1
0
1
0
1
-60
60
-8
8
1
1
1
ticks
30.0

BUTTON
199
314
306
378
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
15
12
167
45
num-cars
num-cars
20
55
50
5
1
NIL
HORIZONTAL

BUTTON
190
385
317
463
drive
drive
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
606
271
919
468
Preferred Speeds
speed (mph)
num cars
10.0
90.0
0.0
30.0
true
true
"" ""
PENS
"speed" 5.0 1 -13210332 true "" "histogram [mph] of turtles"
"min-speed" 5.0 1 -5298144 true "" "histogram [min-speed * mph] of turtles"

MONITOR
605
220
919
265
percent over speed limit
1 - (under-limit / num-cars)
2
1
11

SLIDER
15
52
165
85
acc
acc
.05
.40
0.1
.05
1
NIL
HORIZONTAL

PLOT
351
297
594
468
Prob. of Rubbernecking
probability
num cars
0.0
1.0
0.0
50.0
true
false
"" ""
PENS
"chance to rubberneck" 0.05 1 -16777216 true "" "histogram [prob-neck] of turtles"

SLIDER
352
259
596
292
dist-mean
dist-mean
.01
.50
0.5
.01
1
NIL
HORIZONTAL

SLIDER
352
219
594
252
dist-sd
dist-sd
.01
.1
0.03
.01
1
NIL
HORIZONTAL

SLIDER
14
227
161
260
vision-distance-a
vision-distance-a
0
20
0
1
1
NIL
HORIZONTAL

PLOT
931
220
1169
364
Speed Distribution
speed (mph)
num cars
0.0
90.0
0.0
25.0
false
false
"" ""
PENS
"actual speed" 5.0 1 -16777216 true "" "histogram [speed * speed-limit] of turtles"

SLIDER
16
94
166
127
dec
dec
.05
.40
0.1
.05
1
NIL
HORIZONTAL

MONITOR
1174
224
1344
269
num cars passed this hour
passed
2
1
11

SLIDER
1173
327
1342
360
ticks-per-hour
ticks-per-hour
500
2000
500
100
1
NIL
HORIZONTAL

PLOT
931
368
1395
599
Effective Capacity
hour
num cars
1.0
60.0
60.0
230.0
false
false
"" "if ticks mod ticks-per-hour = 0\n   [\n     set hour hour + 1\n     type \"ticks: \" type ticks type \" hours: \" type hour type \"\\n\"\n     set passed-this-hour passed\n     set passed 0\n     ]"
PENS
"default" 1.0 1 -14070903 true "" "if ticks mod ticks-per-hour = 0\n[ plot passed-this-hour ]"

MONITOR
1174
275
1341
320
hours passed
ticks / ticks-per-hour
2
1
11

SLIDER
15
138
166
171
min-percent
min-percent
.20
.90
0.6
.05
1
NIL
HORIZONTAL

PLOT
6
476
924
600
Average MPH
time
speed
0.0
10.0
40.0
58.0
true
false
"" ""
PENS
"mph" 20.0 0 -16777216 true "" "plot mean [speed * speed-limit] of turtles"

SLIDER
14
186
163
219
split-hours
split-hours
2
50
20
2
1
NIL
HORIZONTAL

SLIDER
14
266
162
299
vision-distance-b
vision-distance-b
0
20
12
1
1
NIL
HORIZONTAL

MONITOR
16
311
163
356
current vision-distance
vision-distance
0
1
11

SLIDER
182
220
340
253
prob-boost
prob-boost
0
.50
0.1
.05
1
NIL
HORIZONTAL

SLIDER
179
261
338
294
merge-threshold
merge-threshold
.85
.99
0.85
.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?
This program attempts to model rubbernecking behavior of vehicles in freeway traffic.

Specifically, it models freeway capacity reduction:
Freeway capacity is defined as the maximum hourly rate at which persons or vehicles can reasonably transverse a point or uniform section of a lane or roadway during a given time period. This capacity reduction is a decrease in the maximum number of vehicles able to pass by a given section of roadway. While maximum possible traffic flow will not change, the actual rate of vehicles passing the specific section of freeway might be reduced due to rubbernecking.

The speed limit is set to 55 mph. The vertical yellow line toward the end of the road is the "checkpoint" line that counts cars as they go by. The red, yellow, orange squares at the middle top are the "distractor" -- that is, the event in the median that is causing the rubbernecking behavior. Additionally, you will notice that cars turn red when rubbernecking.

## HOW IT WORKS
Each car on the road has a hierachy of behaviors. At each tick of the model, each car runs its behavior loop (the drive procedure). The behaviors follow:

1. Can I see the distractor? 
Yes: potentially rubberneck (based on probability distribution and car in front of me).

2. Am I in traffic, i.e. stuck behind slower car(s)? 
Yes, in traffic: 
follow car in front of me, decelerate
potentially merge left or right

3. Otherwise (not in traffic):
Am I rubbernecking? (not in traffic, but rubbernecking). Then do nothing extra.
Otherwise (not in traffic, not rubbernecking), accelerate and drive forward

## HOW TO USE IT
Setup Button: Draws the environment and the cars, distributes the preferred speeds, etc.
Drive Button: Initiates the behavior-loop of each car indefinitely.

=== Setup parameters ===

[num-cars]: The number of cars with which to initially populate the road. This is capped at 55 because going any higher makes it impossible to place all the cars. (default: 50)

[acc]: Percentage of current speed by which cars increase speed when accelerating (default: .10)

[dec]: Percentage of current speed by which cars decrease speed when accelerating (default: .10)

[min-percent]: Each agent's minimum driving speed is calculated by taking a percentage (min-percent) of the agent's preferred speed. (default: .60)

=== Testing parameters ===
The model works by comparing two different conditions (a, b). 

[split-hours]: Each condition runs for split-hours number of hours. (default: 20)

Each agent has a 90-degrees cone of vision that originates -75 degrees from the car's heading (90 degrees, driving east). This cone of vision is sensitive to seeing the distractor in the median.

[vision-distance-a]: How far can the cars see in condition a? 
[vision-distance-b]: How far can the cars see in condition b?

[prob-boost]: Cars check if the cars in front of them are rubbernecking. If they are, this increases the chance that the car will rubberneck by prob-boost. i.e. in this case chance to rubberneck = prob. of rubbernecking + prob-boost.

[merge-threshold]: Probability threshold above which cars will attempt to merge lanes.

[dist-sd]: standard deviation of probability of rubbernecking distribution
[dist-mean]: mean of probability of rubbernecking distribution

[ticks-per-hour]: number of ticks equal to one hour

Steps to Running:
1. choose parameters; crucially: vision-distance-a, vision-distance-b, split-hours
vision-distance-a should be 0 and vision-distance be should be > 0 if you're comparing free-flow capacity (condition a) to rubbernecking capacity (condition b).

2. click setup
3. click drive
4. after (split-hours * 2) number of hours go by, you will see the output in the command center.

## THINGS TO NOTICE
The output in the command center will produce:
Capacity reduction: 1 - (max capacity in condition b / max capacity in condition a)
That is, the percent capacity reduction caused by rubbernecking.

## THINGS TO TRY
Try modifying any of the parameters (esp. vision-distance-b compared to free-flow) in order to see how the capacity reduction changes as a result.

Try modifying the distribution parameters and see if different behaviors emerge.

Try re-running with new setup (i.e. different distributions of preferred speed, prob. of rubbernecking, etc.) and see how the results differ.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
