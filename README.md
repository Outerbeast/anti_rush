# anti_rush
anti_rush custom entity for Sven Co-op

# Getting Started

Registering the entity
- Create a black .as file, name it my_map.as
- Open it and add the following code:-

#include "anti_rush"

void MapInit()
{
   RegisterAntiRushEntity();
}

then save
- In your map cfg, add the code then save:-
map_script my_map
