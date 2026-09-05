extends CardScript
## Death Ward — {W} — Instant — (2ed, common)
## Oracle: Regenerate target creature.
##
## Implementation: RegenerateEffect's targeted variant — the shield lands
## on target creature instead of the effect's source. Cast it in response
## to removal or before blocks; the shield replaces the next destruction
## this turn (tap + clear damage + leave combat, CR 701.15) and expires at
## cleanup like every regeneration shield.
##
## THE 1997 REFUSAL (docs/duel-todo.md §6.8). `@DEATH_WARD`
## (`Program/prompts.txt:238-239`) is two strings, `Select creature.` and
## `Illegal target (not dying).` — a refusal that could not even be
## EXPRESSED before the regeneration window existed, because "dying" is a
## state only that window can see. Inside it, `Duel.hlp`'s topic
## **Regeneration** is the rule: *"You can use regeneration only at the
## time when a creature is about to go to the graveyard."* Outside it —
## and under the modern default, where there is no window at all — Death
## Ward is the ordinary pre-emptive shield it has always been and any
## creature is a legal target.


func build() -> CardData:
	var ward := RegenerateEffect.new().target_creature()
	# `,not dying` is @DEATH_WARD's OWN word, not one of
	# @PROMPT_ILLEGALTARGETWHY's 29: the original gave a handful of cards
	# a bespoke reason of their own, and this is one of them.
	ward.target_spec.with_game_filter(_is_about_to_die).because("not dying")
	return CardData.new("Death Ward", "{W}", Mtg.CardType.INSTANT) \
		.spell(ward) \
		.oracle("Regenerate target creature.")


## Only inside the REGENERATION window does "dying" mean anything; the
## engine's own list of creatures about to go to the graveyard is the
## answer, and it is the same list the window was opened over.
static func _is_about_to_die(game: MtgGame, inst: CardInstance) -> bool:
	if not game.awaiting_regeneration:
		return true
	return game.regeneration_candidates.has(inst.id)
