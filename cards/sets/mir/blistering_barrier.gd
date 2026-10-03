extends CardScript
## Blistering Barrier — {2}{R} — Creature — Wall (common, mir).
## Oracle: Defender (This creature can't attack.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blistering Barrier", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(5, 2)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
