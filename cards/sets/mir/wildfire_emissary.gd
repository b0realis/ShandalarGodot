extends CardScript
## Wildfire Emissary — {3}{R} — Creature — Efreet (uncommon, mir).
## Oracle: Protection from white
##         {1}{R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wildfire Emissary", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 4)
	c.with_subtypes(["efreet"])
	c.with_protection_from(Mtg.ManaColor.W)
	c.oracle("Protection from white\n{1}{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
