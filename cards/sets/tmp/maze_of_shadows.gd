extends CardScript
## Maze of Shadows —  — Land (uncommon, tmp).
## Oracle: {T}: Add {C}.
##         {T}: Untap target attacking creature with shadow. Prevent all combat damage that would be dealt to and dealt by that creature this turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Maze of Shadows", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add {C}.\n{T}: Untap target attacking creature with shadow. Prevent all combat damage that would be dealt to and dealt by that creature this turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
