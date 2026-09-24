extends CardScript
## False Peace — {W} — Sorcery (Portal, 1997).
## Oracle: Target player skips all combat phases of their next turn.

func build() -> CardData:
	var c := CardData.new("False Peace", "{W}", Mtg.CardType.SORCERY)
	c.oracle("Target player skips all combat phases of their next turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
