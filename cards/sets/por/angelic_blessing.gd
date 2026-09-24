extends CardScript
## Angelic Blessing — {2}{W} — Sorcery (Portal, 1997).
## Oracle: Target creature gets +3/+3 and gains flying until end of turn. (It can't be blocked except by creatures with flying or reach.)

func build() -> CardData:
	var c := CardData.new("Angelic Blessing", "{2}{W}", Mtg.CardType.SORCERY)
	c.oracle("Target creature gets +3/+3 and gains flying until end of turn. (It can't be blocked except by creatures with flying or reach.)")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
