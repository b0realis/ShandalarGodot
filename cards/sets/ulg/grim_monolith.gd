extends CardScript
## Grim Monolith — {2} — Artifact (rare, ulg).
## Oracle: This artifact doesn't untap during your untap step.
##         {T}: Add {C}{C}{C}.
##         {4}: Untap this artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Grim Monolith", "{2}", Mtg.CardType.ARTIFACT)
	c.oracle("This artifact doesn't untap during your untap step.\n{T}: Add {C}{C}{C}.\n{4}: Untap this artifact.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
