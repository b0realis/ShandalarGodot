extends CardScript
## Hornet Cannon — {4} — Artifact (uncommon, sth).
## Oracle: {3}, {T}: Create a 1/1 colorless Insect artifact creature token with flying and haste named Hornet. Destroy it at the beginning of the next end step.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hornet Cannon", "{4}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}: Create a 1/1 colorless Insect artifact creature token with flying and haste named Hornet. Destroy it at the beginning of the next end step.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
