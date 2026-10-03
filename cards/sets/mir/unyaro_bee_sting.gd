extends CardScript
## Unyaro Bee Sting — {3}{G} — Sorcery (uncommon, mir).
## Oracle: Unyaro Bee Sting deals 2 damage to any target.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unyaro Bee Sting", "{3}{G}", Mtg.CardType.SORCERY)
	c.oracle("Unyaro Bee Sting deals 2 damage to any target.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
