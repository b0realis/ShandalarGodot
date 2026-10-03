extends CardScript
## Aura of Silence — {1}{W}{W} — Enchantment (uncommon, wth).
## Oracle: Artifact and enchantment spells your opponents cast cost {2} more to cast.
##         Sacrifice this enchantment: Destroy target artifact or enchantment.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aura of Silence", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Artifact and enchantment spells your opponents cast cost {2} more to cast.\nSacrifice this enchantment: Destroy target artifact or enchantment.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
