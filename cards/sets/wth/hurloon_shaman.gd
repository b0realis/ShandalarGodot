extends CardScript
## Hurloon Shaman — {1}{R}{R} — Creature — Minotaur Shaman (uncommon, wth).
## Oracle: When this creature dies, each player sacrifices a land of their choice.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hurloon Shaman", "{1}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["minotaur","shaman"])
	c.oracle("When this creature dies, each player sacrifices a land of their choice.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
