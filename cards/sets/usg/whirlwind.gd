extends CardScript
## Whirlwind — {2}{G}{G} — Sorcery (rare, usg).
## Oracle: Destroy all creatures with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Whirlwind", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures with flying.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
