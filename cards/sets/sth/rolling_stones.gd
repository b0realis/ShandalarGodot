extends CardScript
## Rolling Stones — {1}{W} — Enchantment (rare, sth).
## Oracle: Wall creatures can attack as though they didn't have defender.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rolling Stones", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Wall creatures can attack as though they didn't have defender.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
