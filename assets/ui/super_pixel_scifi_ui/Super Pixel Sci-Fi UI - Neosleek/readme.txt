//////////
// INFO //
//////////

Hello! Thank you for downloading the Super Pixel Sci-fi UI: Neosleek asset pack.
This document contains version history and tips on how to use the asset pack.

Did you know? You can get access to ALL of my assets if you support me on Patreon!
Check it out: patreon.com/untiedgames

MORE LINKS:
Browse my other assets: untiedgames.itch.io
Watch me make pixel art, games, and more: youtube.com/c/unTiedGamesTV
Follow on Mastodon: mastodon.gamedev.place/@untiedgames
Follow on Facebook: facebook.com/untiedgames
Visit my blog: untiedgames.com
Newsletter signup: untiedgames.com/signup

Thanks, and happy game dev!
- Will

/////////////////////
// VERSION HISTORY //
/////////////////////

Version 1.0 (8/17/24)
	- Initial release. Woohoo!
	  This is the first of my UI packs to have combo boxes, scrollbars, item frames, and small meters. Enjoy!

////////////////////////////////
// HOW TO USE THIS ASSET PACK //
////////////////////////////////

Here are a few pointers to help you navigate and make sense of this zip file.

Before starting, I recommend becoming familiar with nine-slices. Read more here: https://en.wikipedia.org/wiki/9-slice_scaling
Buttons, windows, panels, and all other GUI elements in this pack are split into nine "slices." Imagine a 3x3 grid. You can name each grid square as follows: top-left, top-center, top-right, center-left, center, center-right, bottom-left, bottom-center, and bottom-right. You'll notice a lot of files in this zip have names like that! Now, imagine you stretch that 3x3 grid. Imagine that the corner pieces stay the same size, and all other pieces stretch to fit. That's nine-slice scaling! The Wikipedia page linked above has a great picture illustrating this.

--- UNITY USERS ---

The resizable GUI elements in the window_theme folder can be easily used with Unity. Follow the directions in the manual: https://docs.unity3d.com/Manual/9SliceSprites.html
You'll have to assemble/draw the meters manually or use the premade ones.

--- FOLDER BREAKDOWN ---

- controller_glyphs
	- In this folder, you will find different styles of controller graphics, like controller buttons, sticks, and more.
	- Each style is primarily sorted by color.
	- Each style also has an outlined version.
	- Both non-outlined and outlined versions have a corresponding "highlighted" version, where the controller part is a brighter color.

- icons
	- Contains all icons included in the asset pack.
	- In this folder you will find two subfolders, "outlined" and "simple". Choose the icon style you want!
	- In either style folder, you will find icons sorted by color theme.
	- To use them with the buttons in your program, simply draw the icon on top of the button.

- item_frame_cursors
	- Contains cursors to match the item frames found within each window theme.
	- The cursors are not the size indicated in their filename. Rather, this indicates the space which the cursor highlights in the center.
	- For example, item_frame_16x16_cursor goes with item_frame_16x16, which surrounds a 16x16 item.
	- Item frame cursors come in 6 colors and are animated.

- meter
	- In this folder, you will find all the HUD meters in the asset pack. These are useful for displaying a player's HP, energy, mana, and so on.
	- The meter comes in a variety of color themes, so you'll see that all the folders are labeled by color.
	- In each folder is the left, center, and right part of the meter. This works just like 9-slice scaling (see above), but with only 3 slices. This way, you can make the meter as long as you want!
	- Also in the meter folder are colored meter pellets. These come in 6 colors and can be mixed/matched with any of the meters. Draw them multiple times in your game to fill the meter.

- meter_icons
	- This folder contains specially-designed icons that go with the meters.
	- Each meter icon comes in 6 colors.
	- Each meter icon PNG is the same dimensions as each meter's meter_left.png. In your game, you should be able to easily draw meter_left.png and then the meter icon right on top of it at the same coordinates.

- notification
	- Contains some notification graphics. Useful if your game produces notifications!

- premade
	- Contains several premade sizes of all resizable GUI elements (window_theme and meter).
	- Meters can only expand horizontally, so their width will match the folder name but their height won't.

- window_theme
	- We saved the best for last! This folder contains each resizable GUI element, like windows, buttons, message boxes, and so on.
	- Like the other elements, the window theme comes in a variety of colors.
	- PNGs in this folder are either 9-slice images, 3-slice images, or single slice images.
	
	::: 9-slice images, slice size 32x32 :::
		- area.png
		- button_default.png
		- button_disabled.png
		- button_hovered.png
		- button_pressed.png
		- message_box_A.png
		- message_box_B.png
		- panel_focused.png
		- panel_unfocused.png
		- speech_bubble.png
		- subpanel_focused.png
		- subpanel_unfocused.png
		- tab_active.png
		- tab_active_hovered.png
		- tab_inactive.png
		- tab_inactive_hovered.png
		- window.png
		- window_undecorated.png
	
	::: 3-slice images, slice size 16x16 :::
		- combo_box.png
		- combo_box_entry.png
		- scrollbar_horizontal.png
		- scrollbar_vertical.png
		- small_meter_horizontal.png
		- small_meter_vertical.png
	
	::: Single-slice images :::
		- Everything in this folder not listed above. These images can be drawn normally.

- window_theme_sliced
	- Don't want to use 9-slice or 3-slice images? This folder is for you.
	- Each PNG is a single slice, and is named accordingly. For example, the bottom center of the window is named window_bottom_center.png.

Stuck? Check out the example images on the store page to see some examples of how to put the GUI together.

Any questions?
Email me at contact@untiedgames.com and I'll try to answer as best I can!
