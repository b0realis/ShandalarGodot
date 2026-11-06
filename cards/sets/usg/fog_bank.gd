extends CardScript
## Fog Bank — {1}{U} — Creature — Wall (uncommon, usg).
## Oracle: Defender (This creature can't attack.)
##         Flying
##         Prevent all combat damage that would be dealt to and dealt by this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fog Bank", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 2)
	c.with_subtypes(["wall"])
	c.with_keywords([Mtg.Keyword.DEFENDER, Mtg.Keyword.FLYING])
	c.oracle("Defender (This creature can't attack.)\nFlying\nPrevent all combat damage that would be dealt to and dealt by this creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
