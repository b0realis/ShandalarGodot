extends CardScript
## Scragnoth — {4}{G} — Creature — Beast (uncommon, tmp).
## Oracle: This spell can't be countered.
##         Protection from blue
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scragnoth", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 4)
	c.with_subtypes(["beast"])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("This spell can't be countered.\nProtection from blue")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
