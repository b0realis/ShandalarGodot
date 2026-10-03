extends CardScript
## Village Elder — {G} — Creature — Human Druid (common, mir).
## Oracle: {G}, {T}, Sacrifice a Forest: Regenerate target creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Village Elder", "{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","druid"])
	c.oracle("{G}, {T}, Sacrifice a Forest: Regenerate target creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
