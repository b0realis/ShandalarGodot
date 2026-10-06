extends CardScript
## Respite — {1}{G} — Instant (common, tmp).
## Oracle: Prevent all combat damage that would be dealt this turn. You gain 1 life for each attacking creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Respite", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Prevent all combat damage that would be dealt this turn. You gain 1 life for each attacking creature.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
