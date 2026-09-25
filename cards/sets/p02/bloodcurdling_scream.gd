extends CardScript
## Bloodcurdling Scream — {X}{B} — Sorcery (Portal Second Age, 1998).
## Oracle: Target creature gets +X/+0 until end of turn.

func build() -> CardData:
	var c := CardData.new("Bloodcurdling Scream", "{X}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +X/+0 until end of turn.")
	return preload("res://cards/sets/p02/_rules.gd").apply(c)
