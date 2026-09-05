extends CardScript
## Sisters of the Flame — {1}{R}{R} — Creature — Human Shaman — 2/2 (4ed, common; first printed in The Dark)
## Oracle: {T}: Add {R}.
##
## Implementation: a red Llanowar-pattern mana creature (summoning
## sickness applies to the tap, as always).


func build() -> CardData:
	return CardData.new("Sisters of the Flame", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "shaman"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.oracle("{T}: Add {R}.")
