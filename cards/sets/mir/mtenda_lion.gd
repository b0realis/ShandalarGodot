extends CardScript
## Mtenda Lion — {G} — Creature — Cat (common, mir).
## Oracle: Whenever this creature attacks, defending player may pay {U}. If that player does, prevent all combat damage that would be dealt by this creature this turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mtenda Lion", "{G}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["cat"])
	c.oracle("Whenever this creature attacks, defending player may pay {U}. If that player does, prevent all combat damage that would be dealt by this creature this turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
