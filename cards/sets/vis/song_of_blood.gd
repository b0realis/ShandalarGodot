extends CardScript
## Song of Blood — {1}{R} — Sorcery (common, vis).
## Oracle: Mill four cards. Whenever a creature attacks this turn, it gets +1/+0 until end of turn for each creature card put into your graveyard this way.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Song of Blood", "{1}{R}", Mtg.CardType.SORCERY)
	c.oracle("Mill four cards. Whenever a creature attacks this turn, it gets +1/+0 until end of turn for each creature card put into your graveyard this way.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
