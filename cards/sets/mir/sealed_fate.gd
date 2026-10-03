extends CardScript
## Sealed Fate — {X}{U}{B} — Sorcery (uncommon, mir).
## Oracle: Look at the top X cards of target opponent's library. Exile one of those cards and put the rest back on top of that player's library in any order.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sealed Fate", "{X}{U}{B}", Mtg.CardType.SORCERY)
	c.oracle("Look at the top X cards of target opponent's library. Exile one of those cards and put the rest back on top of that player's library in any order.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
