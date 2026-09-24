extends CardScript
## Exhaustion — {2}{U} — Sorcery (Portal, 1997).
## Oracle: Creatures and lands target opponent controls don't untap during their next untap step.

func build() -> CardData:
	var c := CardData.new("Exhaustion", "{2}{U}", Mtg.CardType.SORCERY)
	c.oracle("Creatures and lands target opponent controls don't untap during their next untap step.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
