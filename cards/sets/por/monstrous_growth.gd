extends CardScript
## Monstrous Growth — {1}{G} — Sorcery (Portal, 1997).
## Oracle: Target creature gets +4/+4 until end of turn.

func build() -> CardData:
	var c := CardData.new("Monstrous Growth", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +4/+4 until end of turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
