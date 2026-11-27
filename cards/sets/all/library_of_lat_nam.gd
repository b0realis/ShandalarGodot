extends CardScript
## Library of Lat-Nam — {4}{U} — Sorcery (rare, all).
## Oracle: An opponent chooses one —
##         • You draw three cards at the beginning of the next turn's upkeep.
##         • You search your library for a card, put that card into your hand, then shuffle.
## Trusted optional Pack 5 implementation; ZIPs never provide scripts.
## The opponent chooses the mode as the spell is cast (CR 601.2b):
## CardData.opponent_modes, set by the shared handler (_choices.gd).

func build() -> CardData:
	var c := CardData.new("Library of Lat-Nam", "{4}{U}", Mtg.CardType.SORCERY)
	c.oracle("An opponent chooses one —\n• You draw three cards at the beginning of the next turn's upkeep.\n• You search your library for a card, put that card into your hand, then shuffle.")
	return load("res://cards/sets/all/_rules.gd").apply(c)
