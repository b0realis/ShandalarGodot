extends CardScript
## Season of the Witch — {B}{B}{B} — Enchantment — (drk, rare)
## Oracle: At the beginning of your upkeep, sacrifice this enchantment
##         unless you pay 2 life.
##         At the beginning of the end step, destroy all untapped creatures
##         that didn't attack this turn, except for creatures that couldn't
##         attack.
##
## Implementation: the rent is the engine's usual "unless you pay" trigger,
## paid in LIFE rather than mana. The reaping is an END_STEP_START trigger
## on EVERY turn — the printed line is "the end step", not "your end step".
##
## "Creatures that couldn't attack" is judged AS ATTACKERS WERE DECLARED,
## the only moment a creature can attack (CR 508.1a): MtgGame.
## declare_attackers takes a census of the active player's creatures
## through its own attack predicate (CombatState.attack_illegality plus
## attack costs and Festival-style bans) into CardInstance.
## could_attack_this_turn, whether or not anything attacks. So a creature
## tapped during declare-attackers and untapped afterwards is excused, one
## that could have attacked and was given defender later is not, and a
## creature that arrived after combat never had the chance. Defenders,
## summoning-sick creatures, "can't attack" effects and Wall of Dust bans
## are all excused by the same code that would have refused the
## declaration. (Lifted 2026-09-02; it used to re-run the predicate at the
## end step.)
##
## Only the ACTIVE player's creatures are at risk: nobody else may declare
## attackers at all (CR 508.1a), so every other creature on the board
## "couldn't attack" and is excused. That is what keeps this a punisher for
## holding an army back rather than a one-sided board wipe every turn.


func build() -> CardData:
	return CardData.new("Season of the Witch", "{B}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, sacrifice this enchantment unless you pay 2 life.",
			_your_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _reap,
			"At the beginning of the end step, destroy all untapped creatures that didn't attack this turn, except for creatures that couldn't attack.")) \
		.oracle("At the beginning of your upkeep, sacrifice this enchantment unless "
			+ "you pay 2 life.\nAt the beginning of the end step, destroy all "
			+ "untapped creatures that didn't attack this turn, except for "
			+ "creatures that couldn't attack.")


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _pay_the_rent(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	# Life may legally be paid down to exactly 0 (CR 118.4), but a player
	# who would not survive it is not offered the bargain by the heuristic.
	var hint := game.players[pid].life > 2
	if hint and game.agents[pid].choose_yes_no(game, pid,
			"Pay 2 life to keep Season of the Witch?", hint):
		game.adjust_life(pid, -2)
		return
	game.sacrifice_permanent(source)


static func _reap(game: MtgGame, _source: CardInstance, _event: GameEvent) -> void:
	var pid := game.active_player
	var doomed: Array[CardInstance] = []
	for inst in game.players[pid].battlefield.duplicate():
		if not inst.is_creature() or inst.tapped or inst.attacked_this_turn:
			continue
		if not inst.could_attack_this_turn:   # the declare-attackers census
			continue
		doomed.append(inst)
	if doomed.is_empty():
		return
	game.begin_simultaneous()
	for inst in doomed:
		game.log_line("%s stayed home — Season of the Witch takes it"
			% inst.data.card_name)
		game.destroy(inst)
	game.end_simultaneous()
