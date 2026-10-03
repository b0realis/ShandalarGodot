extends CardScript
## Femeref Archers — {2}{G} — Creature — Human Archer (uncommon, mir).
## Oracle: {T}: This creature deals 4 damage to target attacking creature with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Femeref Archers", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","archer"])
	c.oracle("{T}: This creature deals 4 damage to target attacking creature with flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
