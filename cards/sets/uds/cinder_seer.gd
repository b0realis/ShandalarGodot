extends CardScript
## Cinder Seer — {3}{R} — Creature — Human Wizard (uncommon, uds).
## Oracle: {2}{R}, {T}: Reveal any number of red cards in your hand. This creature deals X damage to any target, where X is the number of cards revealed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cinder Seer", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{2}{R}, {T}: Reveal any number of red cards in your hand. This creature deals X damage to any target, where X is the number of cards revealed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
