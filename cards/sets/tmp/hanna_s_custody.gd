extends CardScript
## Hanna's Custody — {2}{W} — Enchantment (rare, tmp).
## Oracle: All artifacts have shroud. (They can't be the targets of spells or abilities.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hanna's Custody", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("All artifacts have shroud. (They can't be the targets of spells or abilities.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
