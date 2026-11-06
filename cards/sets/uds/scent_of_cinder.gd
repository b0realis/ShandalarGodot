extends CardScript
## Scent of Cinder — {1}{R} — Sorcery (common, uds).
## Oracle: Reveal any number of red cards in your hand. Scent of Cinder deals X damage to any target, where X is the number of cards revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scent of Cinder", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Reveal any number of red cards in your hand. Scent of Cinder deals X damage to any target, where X is the number of cards revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
