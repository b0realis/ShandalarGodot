extends CardScript
## Memory Jar — {5} — Artifact (rare, ulg).
## Oracle: {T}, Sacrifice this artifact: Each player exiles all cards from their hand face down and draws seven cards. At the beginning of the next end step, each player discards their hand and returns to their hand each card they exiled this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Memory Jar", "{5}", Mtg.CardType.ARTIFACT)
	c.oracle("{T}, Sacrifice this artifact: Each player exiles all cards from their hand face down and draws seven cards. At the beginning of the next end step, each player discards their hand and returns to their hand each card they exiled this way.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
