extends CardScript
## Soldevi Sentry — {1} — Artifact Creature — Soldier (common, all).
## Oracle: {1}: Choose target opponent. Regenerate this creature. When it regenerates this way, that player may draw a card.
## Trusted optional Pack 5 implementation; ZIPs never provide scripts.
## SIMPLIFIED (docs/simplified-cards.md, "Soldevi Sentry"): for lethal combat
## damage a human seat is not asked which regeneration shield is used; the
## default is taken (see the regeneration row).

func build() -> CardData:
	var c := CardData.new("Soldevi Sentry", "{1}", Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT)
	c.pt(1, 1)
	c.with_subtypes(["soldier"])
	c.oracle("{1}: Choose target opponent. Regenerate this creature. When it regenerates this way, that player may draw a card.")
	return load("res://cards/sets/all/_rules.gd").apply(c)
