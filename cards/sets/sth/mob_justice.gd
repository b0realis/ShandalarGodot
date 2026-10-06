extends CardScript
## Mob Justice — {1}{R} — Sorcery (common, sth).
## Oracle: Mob Justice deals damage to target player or planeswalker equal to the number of creatures you control.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mob Justice", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Mob Justice deals damage to target player or planeswalker equal to the number of creatures you control.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
