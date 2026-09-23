class_name DualLandTextBox
extends RefCounted
## [QoL] The ten original dual lands' nested, two-color rules panels.
## Geometry observed in the Unlimited Tundra, Badlands and Bayou scans:
## https://scryfall.com/card/2ed/285/tundra
## https://scryfall.com/card/2ed/278/badlands
## https://scryfall.com/card/2ed/279/bayou
## Original procedural drawing, not a crop of those images. Pale inks keep
## our dark rules text readable. No imported skin, card art or RNG required.

const PAIRS := {
	"Tundra": "WU", "Underground Sea": "UB", "Badlands": "RB",
	"Taiga": "RG", "Savannah": "GW", "Scrubland": "WB",
	"Volcanic Island": "UR", "Bayou": "BG", "Plateau": "RW",
	"Tropical Island": "GU",
}
const INKS := {
	"W": Color("eee0bd"), "U": Color("b3cbd6"),
	"B": Color("b8b1af"), "R": Color("dda79a"),
	"G": Color("bdc99c"),
}
const TEXTURE_SIZE := Vector2i(512, 272)
const BAND_WIDTH := 16
## Textures only, never CardData/CardInstance (see CONTRIBUTING.md).
static var _cache: Dictionary = {}


static func texture_for(card_name: String) -> Texture2D:
	if not PAIRS.has(card_name):
		return null
	if _cache.has(card_name):
		return _cache[card_name]
	var pair: String = PAIRS[card_name]
	var img := Image.create(TEXTURE_SIZE.x, TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in TEXTURE_SIZE.y:
		for x in TEXTURE_SIZE.x:
			var edge := mini(mini(x, TEXTURE_SIZE.x - 1 - x),
				mini(y, TEXTURE_SIZE.y - 1 - y))
			var band := int(maxi(edge - 3, 0) / float(BAND_WIDTH)) % 2
			var ink: Color = INKS[pair[band]]
			# Thin inset keyline, then alternating rectangular rings. Equal
			# pixel widths on both axes, as in the old printed rules panel.
			if edge == 0:
				ink = ink.darkened(0.38)
			elif edge == 1:
				ink = ink.lightened(0.20)
			# Tiny deterministic paper grain: no game RNG and no source pixels.
			var grain := float((x * 37 + y * 71 + x * y * 13) % 23 - 11) / 1100.0
			img.set_pixel(x, y, Color(ink.r + grain, ink.g + grain, ink.b + grain))
	var result := ImageTexture.create_from_image(img)
	_cache[card_name] = result
	return result
