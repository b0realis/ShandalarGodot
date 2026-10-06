extends CardScript
## Flame Wave — {3}{R}{R}{R}{R} — Sorcery (uncommon, sth).
## Oracle: Flame Wave deals 4 damage to target player or planeswalker and each creature that player or that planeswalker's controller controls.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flame Wave", "{3}{R}{R}{R}{R}", Mtg.CardType.SORCERY)
	c.oracle("Flame Wave deals 4 damage to target player or planeswalker and each creature that player or that planeswalker's controller controls.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
