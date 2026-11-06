extends CardScript
## Gang of Elk — {5}{G} — Creature — Elk Beast (uncommon, ulg).
## Oracle: Whenever this creature becomes blocked, it gets +2/+2 until end of turn for each creature blocking it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Gang of Elk", "{5}{G}", Mtg.CardType.CREATURE)
	c.pt(5, 4)
	c.with_subtypes(["elk","beast"])
	c.oracle("Whenever this creature becomes blocked, it gets +2/+2 until end of turn for each creature blocking it.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
