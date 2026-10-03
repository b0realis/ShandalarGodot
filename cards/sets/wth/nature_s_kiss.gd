extends CardScript
## Nature's Kiss — {1}{G} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         {1}, Exile the top card of your graveyard: Enchanted creature gets +1/+1 until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Nature's Kiss", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\n{1}, Exile the top card of your graveyard: Enchanted creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
