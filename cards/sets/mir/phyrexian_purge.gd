extends CardScript
## Phyrexian Purge — {2}{B}{R} — Sorcery (rare, mir).
## Oracle: This spell costs 3 life more to cast for each target.
##         Destroy any number of target creatures.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Purge", "{2}{B}{R}", Mtg.CardType.SORCERY)
	c.oracle("This spell costs 3 life more to cast for each target.\nDestroy any number of target creatures.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
