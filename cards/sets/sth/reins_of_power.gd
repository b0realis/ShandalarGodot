extends CardScript
## Reins of Power — {2}{U}{U} — Instant (rare, sth).
## Oracle: Untap all creatures you control and all creatures target opponent controls. You and that opponent each gain control of all creatures the other controls until end of turn. Those creatures gain haste until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Reins of Power", "{2}{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Untap all creatures you control and all creatures target opponent controls. You and that opponent each gain control of all creatures the other controls until end of turn. Those creatures gain haste until end of turn.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
