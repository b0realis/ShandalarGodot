extends CardScript
## Goblin Rock Sled — {1}{R} — Creature — Goblin — 3/1 — (4ed, common)
## Oracle: Trample
##         This creature doesn't untap during your untap step if it attacked
##         during your last turn.
##         This creature can't attack unless defending player controls a
##         Mountain.
##
## Implementation: all three lines. The attack clause is the engine's
## "can't attack unless defending player controls a <land type>" field (Sea
## Serpent's islands); the untap clause rides on the per-turn attacked flag,
## converted into a skip of that player's next untap step as the Sled's
## controller's turn ends.


func build() -> CardData:
	return CardData.new("Goblin Rock Sled", "{1}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 1) \
		.with_subtypes(["goblin"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.with_attack_needs_defender_land("mountain") \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _lock_the_brakes,
			"This creature doesn't untap during your untap step if it attacked during your last turn.",
			_attacked_on_your_turn)) \
		.oracle("Trample\nThis creature doesn't untap during your untap step if it attacked during your last turn.\nThis creature can't attack unless defending player controls a Mountain.")


static func _attacked_on_your_turn(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id \
		and source.attacked_this_turn


## Tied to the SEAT whose turn it attacked in (the bug campaign c12, h3-15):
## "your untap step" is that player's next one, which consumes the skip
## wherever the Sled is by then (MtgGame.skip_untap_during_next_step). The
## bare one-shot flag skipped whichever untap step reached the Sled first —
## a Sled stolen after attacking stayed tapped through its THIEF's untap
## step, though it never attacked during the thief's last turn.
static func _lock_the_brakes(game: MtgGame, source: CardInstance,
		event: GameEvent) -> void:
	game.skip_untap_during_next_step(source, int(event.data["player"]))
