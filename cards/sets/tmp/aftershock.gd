extends CardScript
## Aftershock — {2}{R}{R} — Sorcery (common, tmp).
## Oracle: Destroy target artifact, creature, or land. Aftershock deals 3 damage to you.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Aftershock", "{2}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target artifact, creature, or land. Aftershock deals 3 damage to you.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
