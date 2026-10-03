extends CardScript
## Army Ants — {1}{B}{R} — Creature — Insect (uncommon, vis).
## Oracle: {T}, Sacrifice a land: Destroy target land.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Army Ants", "{1}{B}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["insect"])
	c.oracle("{T}, Sacrifice a land: Destroy target land.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
