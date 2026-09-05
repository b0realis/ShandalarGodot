extends CardScript
## Camouflage — {G} — Instant — (2ed, uncommon)
## Oracle: Cast this spell only during your declare attackers step.
##         This turn, instead of declaring blockers, each defending player
##         chooses any number of creatures they control and divides them
##         into a number of piles equal to the number of attacking
##         creatures … Assign each pile to a different one of those
##         attacking creatures at random. Each creature in a pile that can
##         block the creature that pile is assigned to does so.
##
## Implementation (lifted 2026-09-02; was "combat re-arrangement" in
## docs/simplified-cards.md): the spell only sets
## MtgGame.camouflage_this_turn; the procedure lives in
## MtgGame._camouflage_block_map, which declare_blockers runs INSTEAD of
## the defender's declaration. The defender builds the piles themselves —
## one turn-based OPTION question per creature that could block at all,
## "No pile" or "Pile 1" … "Pile N" for N attackers, held open for a
## human seat like the untap step's questions and re-issued with the
## answers parked — then the piles are dealt to the attackers at random
## (game.rng, so a seeded duel replays the deal), and "each creature in a
## pile that can block the creature that pile is assigned to does so": a
## pile member that can't legally block its attacker stays home. The hint
## per creature is a random pile, which is what the engine used to roll on
## the defender's behalf. Not a 1997 card (no Duel.hlp entry; Manalink's
## unlimited.c only notes "Camouflage --> leave it hardcoded for now").


static func _your_declare_attackers(game: MtgGame, pid: int) -> String:
	if game.active_player != pid:
		return "cast Camouflage only during your turn"
	if game.current_step() != Mtg.Step.DECLARE_ATTACKERS:
		return "cast Camouflage only during your declare attackers step"
	return ""


func build() -> CardData:
	return CardData.new("Camouflage", "{G}", Mtg.CardType.INSTANT) \
		.castable_only_when(_your_declare_attackers) \
		.spell(CamouflageEffect.new()) \
		.oracle("Cast this spell only during your declare attackers step.\nThis turn, instead of declaring blockers, each defending player chooses any number of creatures they control and divides them into a number of piles equal to the number of attacking creatures for whom that player is the defending player. Assign each pile to a different one of those attacking creatures at random. Each creature in a pile that can block the creature that pile is assigned to does so.")


class CamouflageEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.camouflage_this_turn = true
		game.log_line("The defender will divide their creatures into piles this turn")

	func describe() -> String:
		return "the defender divides their creatures into piles, dealt to the attackers at random"
