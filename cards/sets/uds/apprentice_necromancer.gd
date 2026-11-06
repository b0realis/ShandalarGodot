extends CardScript
## Apprentice Necromancer — {1}{B} — Creature — Zombie Wizard (rare, uds).
## Oracle: {B}, {T}, Sacrifice this creature: Return target creature card from your graveyard to the battlefield. That creature gains haste. At the beginning of the next end step, sacrifice it.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Apprentice Necromancer", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["zombie","wizard"])
	c.oracle("{B}, {T}, Sacrifice this creature: Return target creature card from your graveyard to the battlefield. That creature gains haste. At the beginning of the next end step, sacrifice it.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
