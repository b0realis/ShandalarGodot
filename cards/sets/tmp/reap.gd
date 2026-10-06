extends CardScript
## Reap — {1}{G} — Instant (uncommon, tmp).
## Oracle: Return up to X target cards from your graveyard to your hand, where X is the number of black permanents target opponent controls as you cast this spell.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reap", "{1}{G}", Mtg.CardType.INSTANT)
	c.oracle("Return up to X target cards from your graveyard to your hand, where X is the number of black permanents target opponent controls as you cast this spell.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
