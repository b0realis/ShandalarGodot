extends CardScript
## Princess Lucrezia — {3}{U}{U}{B} — Legendary Creature — Human Wizard — 5/4 — (leg, uncommon)
## Oracle: {T}: Add {U}.
##
## Implementation: a ManaAbility (CR 605.3 — stackless). Being a creature,
## the tap is subject to summoning sickness (CR 602.5g), which
## MtgGame.tap_for_mana enforces; the test pins that.


func build() -> CardData:
	return CardData.new("Princess Lucrezia", "{3}{U}{U}{B}", Mtg.CardType.CREATURE) \
		.pt(5, 4) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "wizard"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.oracle("{T}: Add {U}.")
