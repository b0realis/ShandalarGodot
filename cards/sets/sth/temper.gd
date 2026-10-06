extends CardScript
## Temper — {X}{1}{W} — Instant (uncommon, sth).
## Oracle: Prevent the next X damage that would be dealt to target creature this turn. For each 1 damage prevented this way, put a +1/+1 counter on that creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Temper", "{X}{1}{W}", Mtg.CardType.INSTANT)
	c.oracle("Prevent the next X damage that would be dealt to target creature this turn. For each 1 damage prevented this way, put a +1/+1 counter on that creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
