extends CardScript
## Root Maze — {G} — Enchantment (rare, tmp).
## Oracle: Artifacts and lands enter tapped.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Root Maze", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Artifacts and lands enter tapped.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
