extends CardScript
## Renewing Dawn — {1}{W} — Sorcery (Portal, 1997).
## Oracle: You gain 2 life for each Mountain target opponent controls.

func build() -> CardData:
	var c := CardData.new("Renewing Dawn", "{1}{W}", Mtg.CardType.SORCERY)
	c.oracle("You gain 2 life for each Mountain target opponent controls.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
