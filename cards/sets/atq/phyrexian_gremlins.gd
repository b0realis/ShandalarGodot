extends CardScript
## Phyrexian Gremlins — {2}{B} — Creature — Phyrexian Gremlin — 1/1 — (atq, common)
## Oracle: You may choose not to untap this creature during your untap step.
##         {T}: Tap target artifact. It doesn't untap during its
##         controller's untap step for as long as this creature remains
##         tapped.
##
## Implementation: the ability taps the artifact and REMEMBERS it in the
## Gremlins' card-local memory; a static then sets that artifact's
## cur_skips_untap for as long as the Gremlins stay tapped — which
## with_may_skip_untap makes the automatic choice. One artifact
## permanently offline for a 1/1.
##
## "For as long as this creature remains tapped" is a DURATION: the
## moment the Gremlins untap (their untap step, or an Icy-style untap) the
## lock is over for good — attacking with them later does not lock the
## artifact again (CR 611.2b; Manalink's dnuimt_legacy kills the legacy
## the first time its source is untapped). The static that first finds the
## Gremlins untapped forgets the artifact, journaled for the undo log;
## only a fresh activation can hold one again.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s two-line
## form: "Untap <name>." / "Don't untap."); the heuristic keeps it tapped
## while it is sustaining something and untaps it otherwise.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)
	return CardData.new("Phyrexian Gremlins", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["phyrexian", "gremlin"]) \
		.with_may_skip_untap() \
		.static_ability(StaticAbility.new(
			_apply, "The held artifact doesn't untap while the Gremlins stay tapped.")) \
		.activated(ActivatedAbility.new(
			"", true, [HoldEffect.new(spec)],
			"{T}: Tap target artifact. It doesn't untap during its controller's untap "
			+ "step for as long as Phyrexian Gremlins remains tapped.")) \
		.oracle("You may choose not to untap this creature during your untap step.\n"
			+ "{T}: Tap target artifact. It doesn't untap during its controller's "
			+ "untap step for as long as this creature remains tapped.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if not source.memory.has("holding"):
		return
	if not source.tapped:
		# The duration ran out: the lock is over, not paused (CR 611.2b).
		if game.undo_log != null:
			game.undo_log.record(source, &"memory", source.memory)
		source.memory.erase("holding")
		return
	var held := game.find_instance(int(source.memory["holding"]))
	if held != null and held.zone == Mtg.Zone.BATTLEFIELD:
		held.cur_skips_untap = true


class HoldEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var held := game.find_instance(target.instance_id)
		if held == null or held.zone != Mtg.Zone.BATTLEFIELD:
			return
		source.memory["holding"] = held.id
		game.tap_permanent(held)
		game.recalculate()

	func describe() -> String:
		return "taps target artifact and keeps it tapped"
