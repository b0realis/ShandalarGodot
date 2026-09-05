extends CardScript
## Braingeyser — {X}{U}{U} — Sorcery (2ed, rare)
## Oracle: Target player draws X cards.
##
## Implementation: DrawEffect with both the player target and the X flag —
## the X chosen at cast time (MtgGame.cast_spell's x_value, paid from the
## pool on top of {U}{U}) flows through the stack item into the effect.
## Aimable at the opponent as a deck-out weapon, exactly like the original.
## Restricted in Shandalar's deck rules.


func build() -> CardData:
	return CardData.new("Braingeyser", "{X}{U}{U}", Mtg.CardType.SORCERY) \
		.spell(DrawEffect.new(0).target_player().x_cards()) \
		.oracle("Target player draws X cards.")
