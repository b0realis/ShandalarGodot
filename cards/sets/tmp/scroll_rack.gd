extends CardScript
## Scroll Rack — {2} — Artifact (rare, tmp).
## Oracle: {1}, {T}: Exile any number of cards from your hand face down. Put that many cards from the top of your library into your hand. Then look at the exiled cards and put them on top of your library in any order.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scroll Rack", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, {T}: Exile any number of cards from your hand face down. Put that many cards from the top of your library into your hand. Then look at the exiled cards and put them on top of your library in any order.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
