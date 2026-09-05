extends CardScript
## Twiddle — {U} — Instant (2ed, common)
## Oracle: You may tap or untap target artifact, creature, or land.
##
## Implementation: a targeted spell whose MODE — tap or untap — is the
## caster's choice made as it resolves (the ruling on the card: the choice
## is made on resolution, so a Twiddle cast at an untapped creature can
## still untap it if it was tapped in response). Asked with the original's
## own two lines, `@TWIDDLE` (Program/prompts.txt:920): "Tap." / "Untap."
## — and a redundant answer ("Tap." on something already tapped) is legal
## and does nothing, exactly as printed. The heuristic names the mode that
## does something.


func build() -> CardData:
	return CardData.new("Twiddle", "{U}", Mtg.CardType.INSTANT) \
		.spell(TwiddleEffect.new()) \
		.oracle("You may tap or untap target artifact, creature, or land.")


class TwiddleEffect extends EffectBase:
	const MODES: Array[String] = ["Tap.", "Untap."]

	static func _valid_target(inst: CardInstance) -> bool:
		return inst.is_type(Mtg.CardType.ARTIFACT) \
			or inst.is_creature() or inst.is_land()

	func _init() -> void:
		target_spec = TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact, creature, or land", _valid_target)

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		var mode: int = game.agents[controller].choose_option(game, controller,
			MODES, "Twiddle %s: tap or untap?" % inst.data.card_name,
			1 if inst.tapped else 0)
		if mode == 0:
			game.tap_permanent(inst)
		else:
			game.untap_permanent(inst)

	func describe() -> String:
		return "taps or untaps target artifact, creature, or land"
