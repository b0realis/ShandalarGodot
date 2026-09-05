extends CardScript
## Stream of Life — {X}{G} — Sorcery (2ed, common)
## Oracle: Target player gains X life.
##
## Implementation: GainLifeEffect with player target + X mode. Yes, it can
## be aimed at the opponent (it's "target player") — pointless but legal,
## and the engine allows it exactly as the rules do.


func build() -> CardData:
	return CardData.new("Stream of Life", "{X}{G}", Mtg.CardType.SORCERY) \
		.spell(GainLifeEffect.new(0).target_player().x_amount()) \
		.oracle("Target player gains X life.")
