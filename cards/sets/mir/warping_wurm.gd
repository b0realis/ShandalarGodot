extends CardScript
## Warping Wurm — {2}{G}{U} — Creature — Wurm (rare, mir).
## Oracle: Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         At the beginning of your upkeep, this creature phases out unless you pay {2}{G}{U}.
##         Whenever this creature phases in, put a +1/+1 counter on it.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.
## Its phase-in trigger (raised in the untap step) and its upkeep trigger go
## on the stack as one batch in the order its controller chooses (CR 503.1a).

func build() -> CardData:
	var c := CardData.new("Warping Wurm", "{2}{G}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["wurm"])
	c.oracle("Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nAt the beginning of your upkeep, this creature phases out unless you pay {2}{G}{U}.\nWhenever this creature phases in, put a +1/+1 counter on it.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
