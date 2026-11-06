extends CardScript
## Claws of Gix — {0} — Artifact (uncommon, usg).
## Oracle: {1}, Sacrifice a permanent: You gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Claws of Gix", "{0}", Mtg.CardType.ARTIFACT)
	c.oracle("{1}, Sacrifice a permanent: You gain 1 life.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
