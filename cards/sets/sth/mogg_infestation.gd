extends CardScript
## Mogg Infestation — {3}{R}{R} — Sorcery (rare, sth).
## Oracle: Destroy all creatures target player controls. For each creature that died this way, that player creates two 1/1 red Goblin creature tokens.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mogg Infestation", "{3}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Destroy all creatures target player controls. For each creature that died this way, that player creates two 1/1 red Goblin creature tokens.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
