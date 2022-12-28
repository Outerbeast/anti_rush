# anti_rush
![alt text](https://github.com/Outerbeast/anti_rush/blob/main/preview.jpg)
# Getting Started:

To install, download the package from the "Releases" section on the right and extract into `svencoop_addon`
[Download link](https://github.com/Outerbeast/anti_rush/releases/download/v1.1/anti_rush_v1.1.zip)

## Registering the entity
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

# Entity Configuration

`"classname" "anti_rush"`

## Positioning:
| Name | Key | Description |
| ----| :---: | -------- |
| Origin | `"origin" "x y z"`	| Position of the antirush icon sprite |
| Angles | `"angles" "p y r"` | Orientation of the icon. Typically you would just change "y" |
| Zone Radius | `"zoneradius" "r"` | %age trigger zone radius. Default is 512, set value cannot go lower than 16. Radius is used by default if zone bounds are not set/measured incorrectly |
| Percent Trigger Zone Min (X Y Z) | `"zonecornermin" "x1 y1 z1"` | %age trigger zone bounding box min origin (if you are facing 0 degrees, this is the coords of the lower front right corner of the box) |
| Percent Trigger Zone Max (X Y Z) | Same as above but upper back left corner of the box |
| Barrier Min (X Y Z) | `"blockercornermin" "x1 y1 z1"` | Blocker wall bounding box, follows same rules for dimensions as the %age trigger zone |
| Barrier Max (X Y Z) |`"blockercornermax" "x2 y2 z2"` | Blocker wall bounding box, follows same rules for dimensions as the %age trigger zone |

## Logic:
| Name | Key | Description |
| ----| :---: | -------- |
| Name | `"targetname" "trigger_antirush"` | Add a targetname if you want something else, eg game_counter to trigger this |
| Master | `"master" "antirush_master"` | We can lock the %age trigger zone using this (direct trigger is still allowed) |
| Start Trigger |`"netname" "thing(s)_to_target"` | Triggers an entity when the anti_rush entity spawns and becomes active (Optional) |
| Percent Required |`"percentage" "66"` | %age of total players required to trigger. Default is 0 (%age is disabled). |
| Target |`"target" "thing(s)_to_target_or_unlock"` | Triggers a target when %age condition is met or triggered directly (this also has the add bonus of unlocking things with `"master"` that match the target) |
| Blocked Target | `"message" "thing(s)_to_target" | riggers an entity when a player enters the zone for the first time. Each player is passed as activator.
| Lock entities | `"lock" "*m;*n;*o"`	| Locks brush entities that use these models (Only locks `trigger_`s and `func_`s) |
| Kill Target | `"killtarget" "thing(s)_to_delete"` | Deletes an entity when triggered (Optional) |
| Delay Before Trigger | `"delay" "t"` | Time delay in seconds before triggering "target" and "killtarget". |

## Visuals
| Name | Key | Description |
| ----| :---: | -------- |
| Icon | `"icon" "sprites/antirush/percent.spr"` | Sprite to draw (obey env_sprite rules for positioning with origin/angles)- you can use your own sprite, or disable this using "No Icon" flag |
| Sound | `"noise" "buttons/bell1.wav"` | Sound to play when the entity is triggered. This can be disabled using "No Sound" flag. |
| Scale | `"scale" "0.15"` | Scales the icon sprite, default value is `0.15`. |
| Barrier Border Beam Points | `"borderbeampoints" "a b c;d e f;g h i"` | List of points to draw barrier border beams. Minimum is 3 sets of points. |
| Icon Fade Timeout | `"fadetime" "t"` | Time delay in seconds before removing the antirush icon automatically. If border beams are used, those are removed `t + 5` seconds. |

AntiRush icon sprite rendering is done using the standard rendermode, renderamt and rendercolor keys. Below are the default settings:

`"rendermode" "5"`

`"renderamt" "255"`

`"rendercolor" "255 0 0"` This also affects the border beam coloration

## Flags
| Name | Value `"spawnflags" "f"` | Description |
| ----| :---: | -------- |
| Start Off | `1` | Entity starts inactive, trigger to turn it on |
| Don't lock target | `2` | Entity will not lock entities who's master keyvalue matches this entity's target, if master exists. Entities locked via `lock` key are unaffected. |
| No Sound | `4` | Entity will not play a sound when triggered (Alternatively "sound" "sound/null.wav" can be used). |
| No Icon | `8` | Disables the antirush icon (Alternatively "icon" "sprites/null.spr" can be used) |
| Remember Player | `16` | Players who already reached the zone then leave the zone afterwards will still be counted towards the %age |
