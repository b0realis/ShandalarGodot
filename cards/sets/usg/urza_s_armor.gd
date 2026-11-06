extends CardScript
## Urza's Armor — {6} — Artifact (uncommon, usg).
## Oracle: If a source would deal damage to you, prevent 1 of that damage.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Urza's Armor", "{6}", Mtg.CardType.ARTIFACT)
	c.oracle("If a source would deal damage to you, prevent 1 of that damage.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
