extends CardScript
## Suleiman's Legacy — {R}{W} — Enchantment (rare, vis).
## Oracle: When this enchantment enters, destroy all Djinns and Efreets. They can't be regenerated.
##         Whenever a Djinn or Efreet enters, destroy it. It can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Suleiman's Legacy", "{R}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, destroy all Djinns and Efreets. They can't be regenerated.\nWhenever a Djinn or Efreet enters, destroy it. It can't be regenerated.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
