extends CardScript
## Ancestral Recall — {U} — Instant (Alpha, rare; Power Nine)
## Oracle: Target player draws three cards.
##
## Implementation: DrawEffect with a player target — note it can be aimed
## at the opponent (relevant to future deck-out strategies, and to the
## Shandalar AI's misuse of it, which the original game was famous for).
## Restricted in Shandalar's deck rules (restriction handling lands with
## deck validation — docs/ROADMAP.md).


func build() -> CardData:
	return CardData.new("Ancestral Recall", "{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(3).target_player()) \
		.oracle("Target player draws three cards.")
