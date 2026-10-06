extends CardScript
## Auratog — {1}{W} — Creature — Atog (rare, tmp).
## Oracle: Sacrifice an enchantment: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Auratog", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 2)
	c.with_subtypes(["atog"])
	c.oracle("Sacrifice an enchantment: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
