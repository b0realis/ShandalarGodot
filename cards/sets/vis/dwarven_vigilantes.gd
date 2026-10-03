extends CardScript
## Dwarven Vigilantes — {2}{R} — Creature — Dwarf (common, vis).
## Oracle: Whenever this creature attacks and isn't blocked, you may have it deal damage equal to its power to target creature. If you do, this creature assigns no combat damage this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dwarven Vigilantes", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["dwarf"])
	c.oracle("Whenever this creature attacks and isn't blocked, you may have it deal damage equal to its power to target creature. If you do, this creature assigns no combat damage this turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
