extends CardScript
## Mind Rot — {2}{B} — Sorcery (Portal, 1997).
## Oracle: Target player discards two cards.

func build() -> CardData:
	var c := CardData.new("Mind Rot", "{2}{B}", Mtg.CardType.SORCERY)
	c.oracle("Target player discards two cards.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
