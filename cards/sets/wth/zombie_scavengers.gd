extends CardScript
## Zombie Scavengers — {2}{B} — Creature — Zombie (common, wth).
## Oracle: Exile the top creature card of your graveyard: Regenerate this creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Zombie Scavengers", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["zombie"])
	c.oracle("Exile the top creature card of your graveyard: Regenerate this creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
