extends CardScript
## Time Walk — {1}{U} — Sorcery (2ed, rare; Power Nine)
## Oracle: Take an extra turn after this one.
##
## Implementation: ExtraTurnEffect — queues the caster in
## MtgGame.extra_turns; the turn engine services the queue before passing
## the turn (CR 500.7). Multiple Walks queue multiple turns. Two mana for
## a whole turn — restricted in Shandalar's deck rules for obvious reasons,
## and per the dos486 guide the single most game-winning card in the pool.


func build() -> CardData:
	return CardData.new("Time Walk", "{1}{U}", Mtg.CardType.SORCERY) \
		.spell(ExtraTurnEffect.new()) \
		.oracle("Take an extra turn after this one.")
