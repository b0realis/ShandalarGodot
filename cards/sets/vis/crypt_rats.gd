extends CardScript
## Crypt Rats — {2}{B} — Creature — Rat (common, vis).
## Oracle: {X}: This creature deals X damage to each creature and each player. Spend only black mana on X.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Crypt Rats", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["rat"])
	c.oracle("{X}: This creature deals X damage to each creature and each player. Spend only black mana on X.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
