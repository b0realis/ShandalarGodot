extends CardScript
## Field Surgeon — {1}{W} — Creature — Human Cleric (common, uds).
## Oracle: Tap an untapped creature you control: Prevent the next 1 damage that would be dealt to target creature this turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Field Surgeon", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("Tap an untapped creature you control: Prevent the next 1 damage that would be dealt to target creature this turn.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
