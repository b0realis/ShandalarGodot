extends CardScript
## Flash — {1}{U} — Instant (rare, mir).
## Oracle: You may put a creature card from your hand onto the battlefield. If you do, sacrifice it unless you pay its mana cost reduced by {2}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flash", "{1}{U}", Mtg.CardType.INSTANT)
	c.oracle("You may put a creature card from your hand onto the battlefield. If you do, sacrifice it unless you pay its mana cost reduced by {2}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
