class_name PreventCombatDamageEffect
extends EffectBase
## "Prevent all combat damage that would be dealt this turn." — the Fog
## effect (Fog, Holy Day, Darkness, and Angus Mackenzie's activation).
##
## Raises MtgGame.combat_damage_prevented; the combat-damage step checks
## the flag and skips BOTH damage waves (first strike and regular), and
## the cleanup step clears it. Non-combat damage (Bolt, Pestilence) is
## untouched, exactly as printed.


## When set, only the TARGET creature's combat damage is prevented
## (Lady Evangela, Horn of Deafening) instead of the whole combat.
## [member prevent_taken] adds the "dealt TO it" half. Cards that want the
## both-ways shield without a target of their own (Maze of Ith, Ebony Horse)
## call ContinuousEffects.add_until_eot_combat_prevention directly, so
## [method and_to_target] currently has no card in the pool.
var targeted_mode: bool = false
var prevent_dealt: bool = true
var prevent_taken: bool = false


func _init() -> void:
	# One of the three families `Duel.hlp` lets you use in the damage
	# prevention window: "those that prevent, heal, or redirect damage".
	#
	# BUT IT CANNOT ANSWER A PACKET ALREADY ON THE TABLE, and the sentence
	# that stood here — *"A Fog cast in the window prevents the wave that
	# has not landed yet, which is exactly what the window is for"* — hid
	# that (2026-09-01, building the AI's window heuristic). Whole-combat
	# mode raises `MtgGame.combat_damage_prevented`, which
	# `_combat_damage_step` reads BEFORE a wave; the packets waiting in
	# `damage_pending` were planned by a wave that has already run and
	# nothing rechecks the flag for them. So a Fog in the FIRST-STRIKE
	# window really does stop the normal wave — the half the old sentence
	# got right — and a Fog in the normal window is a wasted card.
	# `AiPlayer._spend_on_packet` skips it for exactly that reason.
	is_damage_prevention = true


## Fluent: "prevent all combat damage that would be dealt by target
## creature this turn".
func by_target_creature(spec: TargetSpec = null) -> PreventCombatDamageEffect:
	targeted_mode = true
	target_spec = spec if spec != null else TargetSpec.creature()
	return self


## Fluent: also prevent combat damage dealt TO the target (Maze of Ith).
func and_to_target() -> PreventCombatDamageEffect:
	prevent_taken = true
	return self


## Whole-combat mode sets the MtgGame.combat_damage_prevented flag, which the
## damage step reads before either wave and the cleanup step clears.
## Targeted mode instead registers a floating entry with game.continuous and
## recalculates, which raises the instance's cur_prevent_combat_damage_*
## flags — the same flags Gaseous Form's static ability sets, so
## MtgGame.deal_damage needs only one check for both.
func resolve(game: MtgGame, source: CardInstance, _controller: int,
		target: TargetRef, _x_value: int = 0) -> void:
	if not targeted_mode:
		game.combat_damage_prevented = true
		game.log_line("%s: all combat damage is prevented this turn" % source.data.card_name)
		return
	var inst := game.find_instance(target.instance_id)
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_combat_prevention(inst.id, prevent_dealt, prevent_taken)
	game.recalculate()
	game.log_line("%s: %s's combat damage is prevented this turn" % [
		source.data.card_name, inst.data.card_name])


## One-line log/UI text.
func describe() -> String:
	if targeted_mode:
		return "prevents all combat damage dealt by %s this turn" % target_spec.description
	return "prevents all combat damage this turn"
