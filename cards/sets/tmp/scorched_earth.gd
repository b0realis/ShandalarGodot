extends CardScript
## Scorched Earth — {X}{R} — Sorcery (rare, tmp).
## Oracle: As an additional cost to cast this spell, discard X land cards.
##         Destroy X target lands.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Scorched Earth", "{X}{R}", Mtg.CardType.SORCERY)
	c.oracle("As an additional cost to cast this spell, discard X land cards.\nDestroy X target lands.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
