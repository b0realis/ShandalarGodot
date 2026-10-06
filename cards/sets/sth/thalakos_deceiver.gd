extends CardScript
## Thalakos Deceiver — {3}{U} — Creature — Thalakos Wizard (rare, sth).
## Oracle: Shadow (This creature can block or be blocked by only creatures with shadow.)
##         Whenever this creature attacks and isn't blocked, you may sacrifice it. If you do, gain control of target creature. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thalakos Deceiver", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["thalakos","wizard"])
	c.oracle("Shadow (This creature can block or be blocked by only creatures with shadow.)\nWhenever this creature attacks and isn't blocked, you may sacrifice it. If you do, gain control of target creature. (This effect lasts indefinitely.)")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
