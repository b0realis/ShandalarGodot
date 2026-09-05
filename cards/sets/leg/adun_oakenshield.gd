extends CardScript
## Adun Oakenshield — {B}{R}{G} — Legendary Creature — Human Knight — 1/2 — (leg, rare)
## Oracle: {B}{R}{G}, {T}: Return target creature card from your graveyard
##         to your hand.
##
## Implementation: an ActivatedAbility with both a mana cost and {T},
## carrying ReturnFromGraveyardEffect (Raise Dead's payload). The target
## spec is CREATURE_IN_YOUR_GRAVEYARD, so "your" is enforced by the engine
## against the ability source's owner — Adun can't loot the opponent's
## graveyard. Matches mage-go (legends/creatures.go).


func build() -> CardData:
	return CardData.new("Adun Oakenshield", "{B}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "knight"]) \
		.activated(ActivatedAbility.new(
			"{B}{R}{G}", true,
			[ReturnFromGraveyardEffect.new()],
			"{B}{R}{G}, {T}: Return target creature card from your graveyard to your hand.")) \
		.oracle("{B}{R}{G}, {T}: Return target creature card from your graveyard to your hand.")
