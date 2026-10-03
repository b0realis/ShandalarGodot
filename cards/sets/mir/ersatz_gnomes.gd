extends CardScript
## Ersatz Gnomes — {3} — Artifact Creature — Gnome (uncommon, mir).
## Oracle: {T}: Target spell becomes colorless.
##         {T}: Target permanent becomes colorless until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ersatz Gnomes", "{3}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["gnome"])
	c.oracle("{T}: Target spell becomes colorless.\n{T}: Target permanent becomes colorless until end of turn.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
