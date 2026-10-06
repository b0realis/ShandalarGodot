extends CardScript
## Paladin en-Vec — {1}{W}{W} — Creature — Human Knight (rare, exo).
## Oracle: First strike, protection from black and from red (This creature deals combat damage before creatures without first strike. It can't be blocked, targeted, dealt damage, or enchanted by anything black or red.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Paladin en-Vec", "{1}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.with_protection_from(Mtg.ManaColor.B | Mtg.ManaColor.R)
	c.oracle("First strike, protection from black and from red (This creature deals combat damage before creatures without first strike. It can't be blocked, targeted, dealt damage, or enchanted by anything black or red.)")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
