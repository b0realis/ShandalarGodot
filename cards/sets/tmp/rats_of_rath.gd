extends CardScript
## Rats of Rath — {1}{B} — Creature — Rat (common, tmp).
## Oracle: {B}: Destroy target artifact, creature, or land you control.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rats of Rath", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["rat"])
	c.oracle("{B}: Destroy target artifact, creature, or land you control.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
