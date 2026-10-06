extends CardScript
## Overrun — {2}{G}{G}{G} — Sorcery (uncommon, tmp).
## Oracle: Creatures you control get +3/+3 and gain trample until end of turn. (Each of those creatures can deal excess combat damage to the player or planeswalker it's attacking.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Overrun", "{2}{G}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Creatures you control get +3/+3 and gain trample until end of turn. (Each of those creatures can deal excess combat damage to the player or planeswalker it's attacking.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
