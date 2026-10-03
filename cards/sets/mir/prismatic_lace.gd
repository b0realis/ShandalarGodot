extends CardScript
## Prismatic Lace — {U} — Instant (rare, mir).
## Oracle: Target permanent becomes the color or colors of your choice. (This effect lasts indefinitely.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Prismatic Lace", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Target permanent becomes the color or colors of your choice. (This effect lasts indefinitely.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
