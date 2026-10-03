extends CardScript
## Basalt Golem — {5} — Artifact Creature — Golem (uncommon, mir).
## Oracle: This creature can't be blocked by artifact creatures.
##         Whenever this creature becomes blocked by a creature, that creature's controller sacrifices it at end of combat. If the player does, they create a 0/2 colorless Wall artifact creature token with defender.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Basalt Golem", "{5}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(2, 4)
	c.with_subtypes(["golem"])
	c.oracle("This creature can't be blocked by artifact creatures.\nWhenever this creature becomes blocked by a creature, that creature's controller sacrifices it at end of combat. If the player does, they create a 0/2 colorless Wall artifact creature token with defender.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
