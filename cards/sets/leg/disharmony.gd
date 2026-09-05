extends CardScript
## Disharmony — {2}{R} — Instant — (leg, rare)
## Oracle: Cast this spell only during combat before blockers are declared.
##         Untap target attacking creature and remove it from combat. Gain
##         control of that creature until end of turn.
##
## Implementation: the attacker is untapped, pulled out of combat and lent
## to you for the turn (MtgGame.gain_control_until_eot, which hands it back
## at cleanup even if Disharmony is long gone). It arrives summoning-sick
## under your control, exactly like any other borrowed creature.


static func _is_attacking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)


static func _before_blockers(game: MtgGame, _pid: int) -> String:
	if not Mtg.is_combat_step(game.current_step()):
		return "cast Disharmony only during combat"
	if Mtg.STEP_ORDER.find(game.current_step()) \
			> Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS):
		return "cast Disharmony only before blockers are declared"
	return ""


func build() -> CardData:
	var spec := TargetSpec.creature("target attacking creature")
	spec.with_game_filter(_is_attacking)
	return CardData.new("Disharmony", "{2}{R}", Mtg.CardType.INSTANT) \
		.castable_only_when(_before_blockers) \
		.spell(DisharmonyEffect.new(spec)) \
		.oracle("Cast this spell only during combat before blockers are declared.\nUntap target attacking creature and remove it from combat. Gain control of that creature until end of turn.")


class DisharmonyEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var stolen := game.find_instance(target.instance_id)
		if stolen == null or stolen.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.untap_permanent(stolen)
		game.remove_from_combat(stolen)
		game.gain_control_until_eot(stolen, controller)

	func describe() -> String:
		return "untaps target attacking creature, removes it from combat and borrows it"
