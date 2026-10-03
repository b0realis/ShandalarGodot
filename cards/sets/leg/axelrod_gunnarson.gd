extends CardScript
## Axelrod Gunnarson — {4}{B}{B}{R}{R} — Legendary Creature — Giant — 5/5 — (leg, rare)
## Oracle: Trample
##         Whenever a creature dealt damage by Axelrod Gunnarson this turn
##         dies, you gain 1 life and Axelrod Gunnarson deals 1 damage to
##         target player or planeswalker.
##
## Implementation: the DIES event carries a snapshot of the dead creature's
## `damaged_by_this_turn` list (taken before its battlefield state was
## wiped, CR 608.2h), which is exactly the "dealt damage by Axelrod this
## turn" test — and it works for a creature Axelrod merely wounded that
## something else finished off, which is what the card says.
##
## The trigger fires for a creature Axelrod killed in combat too: the
## dies-check runs after the damage wave, so his own trample victims pay
## him back.
##
## "Target player" is a real TARGET of the trigger
## (TriggeredAbility.targeting): Axelrod's controller names it as the
## trigger goes on the stack (CR 603.3d) — a human seat is asked the
## moment a player would receive priority, as an OPTION list of the two
## names (a player is not a card), with the original's generic prompt
## (`@ANCESTRAL_RECALL`, `Program/prompts.txt`: "Select target player.").
## Either player is legal, yourself included; the list is ranked the
## opponent first, which is the heuristic seat's pick and the human
## seat's default highlight. The life is gained whoever is shot.


func build() -> CardData:
	return CardData.new("Axelrod Gunnarson", "{4}{B}{B}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(5, 5) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["giant"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _reap,
			"Whenever a creature dealt damage by Axelrod Gunnarson this turn dies, you gain 1 life and Axelrod Gunnarson deals 1 damage to target player.",
			_he_wounded_it) \
			.targeting(TargetSpec.player(), _opponent_first,
				"Select target player.")) \
		.oracle("Trample\n"
			+ "Whenever a creature dealt damage by Axelrod Gunnarson this turn dies, you gain "
			+ "1 life and Axelrod Gunnarson deals 1 damage to target player or planeswalker.")


static func _he_wounded_it(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var dead: CardInstance = event.data["instance"]
	if dead == null or (dead.last_types & Mtg.CardType.CREATURE) == 0:
		return false
	return (event.data.get("damaged_by", []) as Array).has(source.id)


## The opponent first — the TRIGGER CONTROLLER's opponent. Axelrod may
## have died in the same wave, his controller_id then reset to his owner;
## a stolen Axelrod's ranking read that and aimed at the thief himself
## until 2026-10-03 (MtgGame.controller_acting_for answers while the
## trigger's targets are ranked).
static func _opponent_first(game: MtgGame, source: CardInstance,
		a: TargetRef, b: TargetRef) -> bool:
	var me := game.controller_acting_for(source)
	var a_enemy := a.player_id != me
	var b_enemy := b.player_id != me
	if a_enemy != b_enemy:
		return a_enemy
	return a.player_id < b.player_id


static func _reap(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	# The trigger resolves even if Axelrod died in the same wave (CR 603.6).
	# "You" is the trigger's CONTROLLER — whoever controlled Axelrod when it
	# triggered — not his owner, which is what a dead Axelrod's reset
	# controller_id reads (a stolen Axelrod paid his owner until 2026-10-03).
	var pid := game.current_resolution_controller()
	if pid < 0:
		pid = source.controller_id
	game.adjust_life(pid, 1)
	var refs: Array = game.current_targets()
	if refs.is_empty():
		return
	game.deal_damage(source, refs[0], 1)
