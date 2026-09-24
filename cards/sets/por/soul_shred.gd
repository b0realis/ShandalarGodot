extends CardScript
## Soul Shred — {3}{B}{B} — Sorcery (Portal, 1997).
## Oracle: Soul Shred deals 3 damage to target nonblack creature. You gain 3 life.

func build() -> CardData:
	var c := CardData.new("Soul Shred", "{3}{B}{B}", Mtg.CardType.SORCERY)
	c.oracle("Soul Shred deals 3 damage to target nonblack creature. You gain 3 life.")
	return preload("res://cards/sets/por/_rules.gd").apply(c)
