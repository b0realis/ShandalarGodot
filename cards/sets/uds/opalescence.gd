extends CardScript
## Opalescence — {2}{W}{W} — Enchantment (rare, uds).
## Oracle: Each other non-Aura enchantment is a creature in addition to its other types and has base power and base toughness each equal to its mana value.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Opalescence", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Each other non-Aura enchantment is a creature in addition to its other types and has base power and base toughness each equal to its mana value.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
