extends CardScript
## Worn Powerstone — {3} — Artifact (uncommon, usg).
## Oracle: This artifact enters tapped.
##         {T}: Add {C}{C}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Worn Powerstone", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("This artifact enters tapped.\n{T}: Add {C}{C}.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
