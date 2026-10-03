extends CardScript
## Goblin Soothsayer — {R} — Creature — Goblin Shaman (uncommon, mir).
## Oracle: {R}, {T}, Sacrifice a Goblin: Red creatures get +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Soothsayer", "{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["goblin","shaman"])
	c.oracle("{R}, {T}, Sacrifice a Goblin: Red creatures get +1/+1 until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
