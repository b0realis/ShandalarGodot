extends CardScript
## Boiling Seas — {3}{R} — Sorcery (Portal, 1997).
## Oracle: Destroy all Islands.

func build() -> CardData:
	var c := CardData.new("Boiling Seas", "{3}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all Islands.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
