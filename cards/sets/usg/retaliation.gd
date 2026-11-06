extends CardScript
## Retaliation — {2}{G} — Enchantment (uncommon, usg).
## Oracle: Creatures you control have "Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn."
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Retaliation", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Creatures you control have \"Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.\"")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
