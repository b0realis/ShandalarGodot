extends CardScript
## Scalebane's Elite — {3}{G}{W} — Creature — Human Soldier (uncommon, vis).
## Oracle: Protection from black
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scalebane's Elite", "{3}{G}{W}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["human","soldier"])
	c.with_protection_from(Mtg.ManaColor.B)
	c.oracle("Protection from black")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
