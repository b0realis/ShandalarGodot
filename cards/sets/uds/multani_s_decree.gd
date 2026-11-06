extends CardScript
## Multani's Decree — {3}{G} — Sorcery (common, uds).
## Oracle: Destroy all enchantments. You gain 2 life for each enchantment destroyed this way.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Multani's Decree", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all enchantments. You gain 2 life for each enchantment destroyed this way.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
