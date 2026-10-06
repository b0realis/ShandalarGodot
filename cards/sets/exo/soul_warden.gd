extends CardScript
## Soul Warden — {W} — Creature — Human Cleric (common, exo).
## Oracle: Whenever another creature enters, you gain 1 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Warden", "{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","cleric"])
	c.oracle("Whenever another creature enters, you gain 1 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
