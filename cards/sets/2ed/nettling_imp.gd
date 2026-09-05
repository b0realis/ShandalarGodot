extends CardScript
## Nettling Imp — {2}{B} — Creature — Imp — 1/1 — (2ed, uncommon)
## Oracle: {T}: Choose target non-Wall creature the active player has
##         controlled continuously since the beginning of the turn. That
##         creature attacks this turn if able. Destroy it at the beginning
##         of the next end step if it didn't attack this turn. Activate
##         only during an opponent's turn, before attackers are declared.
##
## Implementation: the conscription is a per-turn instance flag the engine
## enforces at declare-attackers (CardInstance.must_attack_this_turn), and
## the punishment is the delayed end-step destruction Berserk already uses
## — checked against the same attacked_this_turn flag, so a creature that
## was tapped down after being ordered still dies.


static func _draftable(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.controller_id == game.active_player \
		and inst.controller_id != source.controller_id \
		and not inst.has_subtype("wall") and not inst.summoning_sick


static func _before_attackers(game: MtgGame, pid: int) -> String:
	if game.active_player == pid:
		return "activate only during an opponent's turn"
	if Mtg.STEP_ORDER.find(game.current_step()) \
			>= Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS):
		return "activate only before attackers are declared"
	return ""


func build() -> CardData:
	var spec := TargetSpec.creature("target non-Wall creature the active player controls")
	spec.with_source_filter(_draftable)
	return CardData.new("Nettling Imp", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["imp"]) \
		.activated(ActivatedAbility.new("", true, [NettleEffect.new(spec)],
			"{T}: Target non-Wall creature the active player controls attacks this turn if able, or is destroyed at the beginning of the next end step.") \
			.only_if(_before_attackers_condition)) \
		.oracle("{T}: Choose target non-Wall creature the active player has controlled continuously since the beginning of the turn. That creature attacks this turn if able. Destroy it at the beginning of the next end step if it didn't attack this turn. Activate only during an opponent's turn, before attackers are declared.")


static func _before_attackers_condition(game: MtgGame, source: CardInstance) -> String:
	return _before_attackers(game, source.controller_id)


class NettleEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var conscript := game.find_instance(target.instance_id)
		if conscript == null or conscript.zone != Mtg.Zone.BATTLEFIELD:
			return
		conscript.must_attack_this_turn = true
		game.doom_at_next_end_step_if_it_did_not_attack(conscript)

	func describe() -> String:
		return "target creature attacks this turn or dies at end of turn"
