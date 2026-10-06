extends CardScript
## Wall of Tears — {1}{U} — Creature — Wall (uncommon, sth).
## Oracle: Defender (This creature can't attack.)
##         Whenever this creature blocks a creature, return that creature to its owner's hand at end of combat.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wall of Tears", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 4)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER])
	c.oracle("Defender (This creature can't attack.)\nWhenever this creature blocks a creature, return that creature to its owner's hand at end of combat.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
