extends CardScript
## Tolarian Entrancer — {1}{U} — Creature — Human Wizard (rare, wth).
## Oracle: Whenever this creature becomes blocked by a creature, gain control of that creature at end of combat.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tolarian Entrancer", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("Whenever this creature becomes blocked by a creature, gain control of that creature at end of combat.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
