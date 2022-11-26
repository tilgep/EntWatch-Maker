# EntWatch Maker

Creates a basic EntWatch config for the current map.  
  
This will generate the number of blocks needed for all the items in a map and will fill in some info about them.  
  
Recommended to only use on test servers as the command is available for all players.  

## How to use
- Install the latest [Sourcemod](https://sm.alliedmods.net/downloads.php?branch=stable)
- Install this plugin
- Load the map you want to create a config for
- Make sure that the directory exists before creating a config file
- Use command `sm_ewmake`
- Tweak the generated values for name, color, mode, cooldown, maxuses
- Done

## Configuration
`ewmaker_path`  - a path (relative to `csgo/`) where the configs will generate  
`ewmaker_style` - style of config to generate (0 = [GFL Style](https://github.com/gflclan-cs-go-ze/ZE-Configs#entwatch), 1 = [DarkerZ Style](https://github.com/darkerz7/CSGO-Plugins/blob/master/EntWatch_DZ/cfg/sourcemod/entwatch/maps/template.txt), 2 = Mapeadores MapTrack)
