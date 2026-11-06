extends CardScript
## Raze — {R} — Sorcery (common, usg).
## Oracle: As an additional cost to cast this spell, sacrifice a land.
##         Destroy target land.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Raze", "{R}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, sacrifice a land.\nDestroy target land.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
