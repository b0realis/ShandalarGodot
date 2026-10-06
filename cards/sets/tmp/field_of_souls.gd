extends CardScript
## Field of Souls — {2}{W}{W} — Enchantment (rare, tmp).
## Oracle: Whenever a nontoken creature is put into your graveyard from the battlefield, create a 1/1 white Spirit creature token with flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Field of Souls", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a nontoken creature is put into your graveyard from the battlefield, create a 1/1 white Spirit creature token with flying.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
