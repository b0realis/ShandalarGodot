extends CardScript
## Coffin Queen — {2}{B} — Creature — Zombie Wizard (rare, tmp).
## Oracle: You may choose not to untap this creature during your untap step.
##         {2}{B}, {T}: Put target creature card from a graveyard onto the battlefield under your control. When this creature becomes untapped or you lose control of this creature, exile that creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Coffin Queen", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["zombie","wizard"])
	c.oracle("You may choose not to untap this creature during your untap step.\n{2}{B}, {T}: Put target creature card from a graveyard onto the battlefield under your control. When this creature becomes untapped or you lose control of this creature, exile that creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
