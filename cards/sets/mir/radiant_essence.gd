extends CardScript
## Radiant Essence — {1}{G}{W} — Creature — Spirit (uncommon, mir).
## Oracle: This creature gets +1/+2 as long as an opponent controls a black permanent.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Radiant Essence", "{1}{G}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["spirit"])
	c.oracle("This creature gets +1/+2 as long as an opponent controls a black permanent.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
