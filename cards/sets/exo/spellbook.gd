extends CardScript
## Spellbook — {0} — Artifact — Book (uncommon, exo).
## Oracle: You have no maximum hand size.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spellbook", "{0}", Mtg.CardType.ARTIFACT)
	c.with_subtypes(["book"])
	c.oracle("You have no maximum hand size.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
