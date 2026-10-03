extends CardScript
## Nettletooth Djinn — {3}{G} — Creature — Djinn (uncommon, mir).
## Oracle: At the beginning of your upkeep, this creature deals 1 damage to you.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nettletooth Djinn", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["djinn"])
	c.oracle("At the beginning of your upkeep, this creature deals 1 damage to you.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
