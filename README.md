# anti_rush

# Getting Started:

To install Download the package and extract into maps

Registering the entity
- Create a blank .as file, name it my_map.as
- Open it and add the following code:-
```
#include "anti_rush"

void MapInit()
{
   ANTI_RUSH::EntityRegister();
}
```
then save
- In your map cfg, add the code then save:-
`map_script my_map`

# Keys:-

`"classname" "anti_rush"`

## Positioning:

`"origin" "x y z"`						- Position of the antirush icon sprite

`"angles" "p y r"`							- Orientation of the icon. Typically you would just change "y"

`"zoneradius" "r"`							- %age trigger zone radius. Default is 512, set value cannot go lower than 16. Radius is used by default if zone bounds are not defined/measured incorrectly

`"zonecornermin" "x1 y1 z1"`				- %age trigger zone bounding box min origin (if you are facing 0 degrees, this is the coords of the lower front right corner of the box)

`"zonecornermax" "x2 y2 z2"`				- Same as above but upper back left corner of the box

`"blockercornermin" "x1 y1 z1"`			- Blocker wall bounding box, follows same rules for dimensions as the %age trigger zone

`"blockercornermax" "x2 y2 z2"`			- Blocker wall bounding box, follows same rules for dimensions as the %age trigger zone

## Logic:

`"targetname" "trigger_antirush"` - Add a targetname if you want something else, eg game_counter to trigger this

`"master" "antirush_master"`				- We can lock the %age trigger zone using this (direct trigger is still allowed)		

`"netname" "thing_to_target"`				- Triggers an entity when the anti_rush entity spawns and becomes active (Optional)

`"percentage" "66"`						- %age of total players required to trigger. Default is 0 (%age is disabled).

`"target" "thing(s)_to_target_or_unlock"`	- Triggers a target when %age condition is met or triggered directly (this also has the add bonus of unlocking things with	 that match the target)

`"master" antirush_master`- We can lock the %age trigger zone using this (direct trigger is still allowed)

`"lock" "*m;*n;*o"`						- Locks brush entities that use these models

`"killtarget" "thing(s)_to_delete"`		- Deletes an entity when triggered (Optional)

## Visuals

`"icon" "sprites/antirush/percent.spr"`	- Sprite to draw (obey env_sprite rules for positioning with origin/angles)- you can use your own sprite, or disable this using "No Icon" flag
`"sound" "buttons/bell1.wav"`				- Sound to play when the entity is triggered. This can be disabled using "No Sound" flag.

`"borderbeampoints" "a b c;d e f;g h i;"`	- List of points to draw barrier border beams. Minimum is 3 sets of points.

`"sound" "buttons/bell1.wav"`				- Sound to play when the entity is triggered. This can be disabled using "No Sound" flag.

`"borderbeampoints" "a b c;d e f;g h i;"`	- List of points to draw barrier border beams. Minimum is 3 sets of points.

AntiRush icon sprite rendering is done using the standard rendermode, renderamt and rendercolor keys. Below are the default settings:
`"rendermode" "5"`

`"renderamt" "255"`

`"rendercolor" "255 0 0"` This also affects the border beam coloration

## Flags
`"spawnflags" "f"`	- See below for flags for various settings


`"1"` - "Start Off": Entity starts inactive, trigger to turn it on

`"2"` - "Don't lock target": Entity will not lock entities who's master keyvalue matches this entity's target, if master exists

`"4"` - "No Sound": Entity will not play a sound when triggered (Alternatively "sound" "sound/null.wav" can be used)

`"8"` - "No Icon" : Disables the antirush icon (Alternatively "icon" "sprites/null.spr" can be used)
