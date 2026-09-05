extends CardScript
## Voodoo Doll — {6} — Artifact — (leg, rare)
## Oracle: At the beginning of your upkeep, put a pin counter on this
##         artifact.
##         At the beginning of your end step, if this artifact is untapped,
##         destroy this artifact and it deals damage to you equal to the
##         number of pin counters on it.
##         {X}{X}, {T}: This artifact deals damage equal to the number of
##         pin counters on it to any target. X is the number of pin counters
##         on this artifact.
##
## Implementation: all three lines. The doubled {X}{X} really charges twice
## (ManaCost.x_count), and the damage is the pin count — so the Doll gets
## more expensive and more dangerous every turn, and leaving it untapped at
## your end step is what kills you.
##
## "X is the number of pin counters on this artifact" is not advice, it is a
## constraint: the ability is REFUSED (CONTRIBUTING.md rule 3) unless the X named
## equals the pin count, through ActivatedAbility.with_x_condition. Without
## it X=0 fired the Doll for free, which is the one line nobody would ever
## not take.


func build() -> CardData:
	return CardData.new("Voodoo Doll", "{6}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _stick_a_pin,
			"At the beginning of your upkeep, put a pin counter on this artifact.",
			_your_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _backfire,
			"At the beginning of your end step, if this artifact is untapped, destroy it and it deals damage to you equal to the number of pin counters on it.",
			_your_end_step_untapped)) \
		.activated(ActivatedAbility.new("{X}{X}", true, [PinDamageEffect.new()],
			"{X}{X}, {T}: This artifact deals damage equal to the number of pin counters on it to any target. X is the number of pin counters on this artifact.") \
			.with_x_condition(_x_is_the_pin_count)) \
		.oracle("At the beginning of your upkeep, put a pin counter on this artifact.\nAt the beginning of your end step, if this artifact is untapped, destroy this artifact and it deals damage to you equal to the number of pin counters on it.\n{X}{X}, {T}: This artifact deals damage equal to the number of pin counters on it to any target. X is the number of pin counters on this artifact.")


## "X is the number of pin counters on this artifact" — a hard constraint on
## the activation, not a default (CR 601.2b: the value of X is announced,
## and an announcement the card forbids is an illegal activation).
static func _x_is_the_pin_count(_game: MtgGame, source: CardInstance,
		x_value: int, _targets: Array) -> String:
	var pins := int(source.counters.get("pin", 0))
	if x_value != pins:
		return "X must be %d — the number of pin counters on %s" % [
			pins, source.data.card_name]
	return ""


static func _your_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _your_end_step_untapped(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id and not source.tapped


static func _stick_a_pin(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "pin", 1)


static func _backfire(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD or source.tapped:
		return
	var pins := int(source.counters.get("pin", 0))
	var owner := source.controller_id
	game.destroy(source)
	if pins > 0:
		game.deal_damage(source, TargetRef.player(owner), pins)


class PinDamageEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pins := int(source.counters.get("pin", 0))
		if pins > 0:
			game.deal_damage(source, target, pins)

	func describe() -> String:
		return "deals damage equal to its pin counters to any target"
