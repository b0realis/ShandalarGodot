extends CardScript
## Rootwater Hunter — {2}{U} — Creature — Merfolk (common, tmp).
## Oracle: {T}: This creature deals 1 damage to any target.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwater Hunter", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["merfolk"])
	c.oracle("{T}: This creature deals 1 damage to any target.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
