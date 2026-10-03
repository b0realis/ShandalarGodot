extends CardScript
## Creeping Mold — {2}{G}{G} — Sorcery (uncommon, vis).
## Oracle: Destroy target artifact, enchantment, or land.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Creeping Mold", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy target artifact, enchantment, or land.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
