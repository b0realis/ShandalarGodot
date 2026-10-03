extends CardScript
## Natural Balance — {2}{G}{G} — Sorcery (rare, mir).
## Oracle: Each player who controls six or more lands chooses five lands they control and sacrifices the rest. Each player who controls four or fewer lands may search their library for up to X basic land cards and put them onto the battlefield, where X is five minus the number of lands they control. Then each player who searched their library this way shuffles.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Natural Balance", "{2}{G}{G}", Mtg.CardType.SORCERY)
	c.oracle("Each player who controls six or more lands chooses five lands they control and sacrifices the rest. Each player who controls four or fewer lands may search their library for up to X basic land cards and put them onto the battlefield, where X is five minus the number of lands they control. Then each player who searched their library this way shuffles.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
