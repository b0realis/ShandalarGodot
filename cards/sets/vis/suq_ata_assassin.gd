extends CardScript
## Suq'Ata Assassin — {1}{B}{B} — Creature — Human Assassin (uncommon, vis).
## Oracle: Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)
##         Whenever this creature attacks and isn't blocked, defending player gets a poison counter. (A player with ten or more poison counters loses the game.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Suq'Ata Assassin", "{1}{B}{B}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","assassin"])
	c.with_keywords([Mtg.Keyword.FEAR])
	c.oracle("Fear (This creature can't be blocked except by artifact creatures and/or black creatures.)\nWhenever this creature attacks and isn't blocked, defending player gets a poison counter. (A player with ten or more poison counters loses the game.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
