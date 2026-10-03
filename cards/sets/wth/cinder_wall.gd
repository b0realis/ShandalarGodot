extends CardScript
## Cinder Wall — {R} — Creature — Wall (common, wth).
## Oracle: Defender
##         When this creature blocks, destroy it at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cinder Wall", "{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender\nWhen this creature blocks, destroy it at end of combat.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
