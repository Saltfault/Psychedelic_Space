//////////
// INFO //
//////////

Hello! Thank you for downloading the Super Pixel Item Pickups: Sci-fi Pack 1 asset pack.
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

Version 2.0 (4/9/23)
	- Added the following additional color themes for the item pickups:
		- Atom red
		- Atom yellow
		- Atom blue
		- Atom gray
		- Bolt red
		- Bolt orange
		- Bolt yellow
		- Bolt green
		- Bolt blue
		- Bolt violet
		- Energy canister A red (large + small)
		- Energy canister A orange (large + small)
		- Energy canister A blue (large + small)
		- Energy canister B orange (large + small)
		- Energy canister B green (large + small)
		- Energy canister B violet (large + small)
		- Energy orb gray
		- Energy orb red
		- Energy orb orange
		- Energy orb blue
		- Gadget A red
		- Gadget A orange
		- Gadget A green
		- Gadget B red
		- Gadget B orange
		- Gadget B blue
		- Gear red
		- Gear orange
		- Gear yellow
		- Gear green
		- Gear blue
		- Gear violet
		- Missile tank orange
		- Missile tank yellow
		- Missile tank blue
		- Nut red
		- Nut orange
		- Nut yellow
		- Nut green
		- Nut blue
		- Nut violet

Version 1.0 (3/10/23)
	- Initial release. Woohoo!

////////////////////////////////
// HOW TO USE THIS ASSET PACK //
////////////////////////////////

Here are a few pointers to help you navigate and make sense of this zip file.

- In the root folder, you will find folders named PNG and spritesheet.

- The PNG folder contains all the item animations separated into their own folders, with the frames as individual PNG files.

- The spritesheet folder contains all the item animations separated into their own folders, but with the frames packed into a single image. A metadata file is alongside each spritesheet which may be used to parse the image.

- The spritesheets are provided as an alternate method of loading the images into your game.
  Each line of a spritesheet's metadata file will look like the following example:
	
	image.png = 0 32 16 24

  The format is:

	path = x y w h

  ...Where path is the path to the file (with extension). X and Y represent the upper left corner (in pixels) of the image on the sheet. W and H represent the width and height of the image on the sheet (in pixels).
  So in our example above, we could locate image.png on our spritesheet. Its upper left corner would be (0, 32) and it would have a size of 16x24.

- Recommended animation FPS: 15 (66.7 ms/frame)

Any questions?
Email me at contact@untiedgames.com and I'll try to answer as best I can!

-Will