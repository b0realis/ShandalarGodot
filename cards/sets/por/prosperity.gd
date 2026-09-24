extends CardScript
## Prosperity — {X}{U} — Sorcery (Portal, 1997).
## Oracle: Each player draws X cards.

func build() -> CardData:
	var c := CardData.new("Prosperity", "{X}{U}", Mtg.CardType.SORCERY)
	c.oracle("Each player draws X cards.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
