extends CardScript
## Riven Turnbull — {5}{U}{B} — Legendary Creature — Human Advisor — 5/7 — (leg, uncommon)
## Oracle: {T}: Add {B}.
##
## Implementation: a ManaAbility, exactly like Princess Lucrezia's. A 5/7
## body that ramps one black — seven mana for the privilege.


func build() -> CardData:
	return CardData.new("Riven Turnbull", "{5}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(5, 7) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "advisor"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.oracle("{T}: Add {B}.")
