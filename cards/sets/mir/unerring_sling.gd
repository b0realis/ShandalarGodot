extends CardScript
## Unerring Sling — {3} — Artifact (uncommon, mir).
## Oracle: {3}, {T}, Tap an untapped creature you control: This artifact deals damage equal to the tapped creature's power to target attacking or blocking creature with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Unerring Sling", "{3}", Mtg.CardType.ARTIFACT)
	c.oracle("{3}, {T}, Tap an untapped creature you control: This artifact deals damage equal to the tapped creature's power to target attacking or blocking creature with flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
