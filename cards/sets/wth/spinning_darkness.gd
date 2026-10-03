extends CardScript
## Spinning Darkness — {4}{B}{B} — Instant (common, wth).
## Oracle: You may exile the top three black cards of your graveyard rather than pay this spell's mana cost.
##         Spinning Darkness deals 3 damage to target nonblack creature. You gain 3 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spinning Darkness", "{4}{B}{B}", Mtg.CardType.INSTANT)
	c.oracle("You may exile the top three black cards of your graveyard rather than pay this spell's mana cost.\nSpinning Darkness deals 3 damage to target nonblack creature. You gain 3 life.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
