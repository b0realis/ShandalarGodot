extends CardScript
## Phyrexian Tribute — {2}{B} — Sorcery (rare, mir).
## Oracle: As an additional cost to cast this spell, sacrifice two creatures.
##         Destroy target artifact.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Tribute", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice two creatures.\nDestroy target artifact.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
