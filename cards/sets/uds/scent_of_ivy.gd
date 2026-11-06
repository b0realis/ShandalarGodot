extends CardScript
## Scent of Ivy — {G} — Instant (common, uds).
## Oracle: Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scent of Ivy", "{G}", Mtg.CardType.INSTANT)
	c.oracle("Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
