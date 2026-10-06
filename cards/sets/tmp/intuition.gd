extends CardScript
## Intuition — {2}{U} — Instant (rare, tmp).
## Oracle: Search your library for three cards and reveal them. Target opponent chooses one. Put that card into your hand and the rest into your graveyard. Then shuffle.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Intuition", "{2}{U}", Mtg.CardType.INSTANT)
	c.oracle("Search your library for three cards and reveal them. Target opponent chooses one. Put that card into your hand and the rest into your graveyard. Then shuffle.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
