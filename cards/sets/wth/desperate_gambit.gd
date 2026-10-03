extends CardScript
## Desperate Gambit — {R} — Instant (uncommon, wth).
## Oracle: Choose a source you control and flip a coin. If you win the flip, the next time that source would deal damage this turn, it deals double that damage instead. If you lose the flip, the next time it would deal damage this turn, prevent that damage.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Desperate Gambit", "{R}", Mtg.CardType.INSTANT)
	c.oracle("Choose a source you control and flip a coin. If you win the flip, the next time that source would deal damage this turn, it deals double that damage instead. If you lose the flip, the next time it would deal damage this turn, prevent that damage.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
