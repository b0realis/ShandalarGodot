extends CardScript
## Guma — {2}{R} — Creature — Cat (uncommon, usg).
## Oracle: Protection from blue
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Guma", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["cat"])
	c.with_protection_from(Mtg.ManaColor.U)
	c.oracle("Protection from blue")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
