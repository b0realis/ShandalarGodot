extends CardScript
## Argothian Wurm — {3}{G} — Creature — Wurm (rare, usg).
## Oracle: Trample
##         When this creature enters, any player may sacrifice a land of their choice. If a player does, put this creature on top of its owner's library.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argothian Wurm", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(6, 6)
	c.with_subtypes(["wurm"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample\nWhen this creature enters, any player may sacrifice a land of their choice. If a player does, put this creature on top of its owner's library.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
