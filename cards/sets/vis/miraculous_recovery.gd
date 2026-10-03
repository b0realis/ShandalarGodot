extends CardScript
## Miraculous Recovery — {4}{W} — Instant (uncommon, vis).
## Oracle: Return target creature card from your graveyard to the battlefield. Put a +1/+1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Miraculous Recovery", "{4}{W}", Mtg.CardType.INSTANT)
	c.oracle("Return target creature card from your graveyard to the battlefield. Put a +1/+1 counter on it.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
