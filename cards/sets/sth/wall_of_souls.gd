extends CardScript
## Wall of Souls — {1}{B} — Creature — Wall (uncommon, sth).
## Oracle: Defender (This creature can't attack.)
##         Whenever this creature is dealt combat damage, it deals that much damage to target opponent or planeswalker.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Souls", "{1}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nWhenever this creature is dealt combat damage, it deals that much damage to target opponent or planeswalker.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
