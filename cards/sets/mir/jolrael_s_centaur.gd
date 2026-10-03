extends CardScript
## Jolrael's Centaur — {1}{G}{G} — Creature — Centaur Archer (common, mir).
## Oracle: Shroud (This creature can't be the target of spells or abilities.)
##         Flanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Jolrael's Centaur", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["centaur","archer"])
	c.oracle("Shroud (This creature can't be the target of spells or abilities.)\nFlanking (Whenever a creature without flanking blocks this creature, the blocking creature gets -1/-1 until end of turn.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
