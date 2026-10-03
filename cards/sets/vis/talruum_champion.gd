extends CardScript
## Talruum Champion — {4}{R} — Creature — Minotaur (common, vis).
## Oracle: First strike
##         Whenever this creature blocks or becomes blocked by a creature, that creature loses first strike until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Talruum Champion", "{4}{R}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["minotaur"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike\nWhenever this creature blocks or becomes blocked by a creature, that creature loses first strike until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
