extends CardScript
## Xira Arien — {B}{R}{G} — Legendary Creature — Insect Wizard — 1/2 — (leg, rare)
## Oracle: Flying
##         {B}{R}{G}, {T}: Target player draws a card.
##
## Implementation: printed flying plus a targeted DrawEffect. The draw
## targets a PLAYER (either one — Xira is famously a group-hug card in
## multiplayer; in a duel it can gift the opponent a card, which the AI
## evaluator is free to consider a bad idea). Matches mage-go.


func build() -> CardData:
	return CardData.new("Xira Arien", "{B}{R}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["insect", "wizard"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.activated(ActivatedAbility.new(
			"{B}{R}{G}", true,
			[DrawEffect.new(1).target_player()],
			"{B}{R}{G}, {T}: Target player draws a card.")) \
		.oracle("Flying\n{B}{R}{G}, {T}: Target player draws a card.")
