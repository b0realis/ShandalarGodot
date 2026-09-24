extends CardScript
## Tidal Surge — {1}{U} — Sorcery (Portal, 1997).
## Oracle: Tap up to three target creatures without flying.

func build() -> CardData:
	var c := CardData.new("Tidal Surge", "{1}{U}", Mtg.CardType.SORCERY)
	c.oracle("Tap up to three target creatures without flying.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
