extends CardScript
## Summer Bloom — {1}{G} — Sorcery (Portal, 1997).
## Oracle: You may play up to three additional lands this turn.

func build() -> CardData:
	var c := CardData.new("Summer Bloom", "{1}{G}", Mtg.CardType.SORCERY)
	c.oracle("You may play up to three additional lands this turn.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
