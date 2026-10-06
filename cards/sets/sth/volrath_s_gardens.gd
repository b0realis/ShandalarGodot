extends CardScript
## Volrath's Gardens — {1}{G} — Enchantment (rare, sth).
## Oracle: {2}, Tap an untapped creature you control: You gain 2 life. Activate only as a sorcery.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Volrath's Gardens", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}, Tap an untapped creature you control: You gain 2 life. Activate only as a sorcery.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
