extends CardScript
## Superior Numbers — {G}{G} — Sorcery (uncommon, mir).
## Oracle: Superior Numbers deals damage to target creature equal to the number of creatures you control in excess of the number of creatures target opponent controls.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Superior Numbers", "{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Superior Numbers deals damage to target creature equal to the number of creatures you control in excess of the number of creatures target opponent controls.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
