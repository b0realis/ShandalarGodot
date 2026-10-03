extends CardScript
## Karoo Meerkat — {1}{G} — Creature — Mongoose (uncommon, mir).
## Oracle: Protection from blue
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Karoo Meerkat", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["mongoose"])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("Protection from blue")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
