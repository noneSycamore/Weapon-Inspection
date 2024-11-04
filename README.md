# Weapon Inspection mod for Cyberpunk 2077

Similar to: [Always First Equip](https://www.nexusmods.com/cyberpunk2077/mods/2557), but without complicated settings.

## This time, V triggers the FirstEquip animation every time the weapon is equipped, instead of probabilistically or cooltime.

## The FirstEquip animation will be triggered every time the shortcut key is pressed, just like weapon inspection.

Although CP2077 can also achive this after updates, by holding the unsheathe button, but we have to sheathe the weapon first, and this is too bulky !!!

If you want to change the button: 
1. go to "<Cyberpunk 2077>\r6\input" folder
2. open "WeaponInspection.xml" with any text editor
3. find and replace "IK_Y" with any other hotkey codes

Hotkeys reference list is [available here](https://nativedb.red4ext.com/EInputKey)

If you want to change the animation for inspection:
1. go to "<Cyberpunk 2077>\r6\scripts\Weapon Inspection" folder
2. open "WeaponInspection.reds" with any text editor
3. find variable "ifOtherAnim" and change its value to true
4. find variable "animationName" and change its value to the animation you want

## And this is an unfinished mod.
Cause I am not satisfied with the inspection animation I found for ranged weapons.

FirstEquip anim looks weird, IdleBreak and SafeAction are too simple.

Maybe I have to make new animations for some weapons, but there are so many of them. 

Or maybe this mod will end up like this.