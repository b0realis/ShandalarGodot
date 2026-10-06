extends CardScript
## Ertai's Meddling — {X}{U} — Instant (rare, tmp).
## Oracle: X can't be 0.
##         Target spell's controller exiles it with X delay counters on it.
##         At the beginning of each of that player's upkeeps, if that card is exiled, remove a delay counter from it. If the card has no delay counters on it, the player puts it onto the stack as a copy of the original spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ertai's Meddling", "{X}{U}", Mtg.CardType.INSTANT)
	c.oracle("X can't be 0.\nTarget spell's controller exiles it with X delay counters on it.\nAt the beginning of each of that player's upkeeps, if that card is exiled, remove a delay counter from it. If the card has no delay counters on it, the player puts it onto the stack as a copy of the original spell.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
