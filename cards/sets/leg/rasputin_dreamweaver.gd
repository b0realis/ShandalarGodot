extends CardScript
## Rasputin Dreamweaver — {4}{W}{U} — Legendary Creature — Human Wizard — 4/1 — (leg, rare)
## Oracle: Rasputin enters with seven dream counters on it.
##         Remove a dream counter from Rasputin: Add {C}.
##         Remove a dream counter from Rasputin: Prevent the next 1 damage
##         that would be dealt to Rasputin this turn.
##         At the beginning of your upkeep, if Rasputin started the turn
##         untapped, put a dream counter on it.
##         Rasputin can't have more than seven dream counters on it.
##
## Implementation: all five lines. The mana ability pays a dream counter
## instead of tapping (ManaAbility.with_counter_cost, new in this wave), so
## Rasputin can bank mana without ever tapping; the shield ability spends
## the same currency into the engine's damage-prevention pool; the upkeep
## refill respects the seven-counter cap.
##
## "STARTED THE TURN untapped" cannot be read at the upkeep — the untap
## step has already freed him by then — and the engine keeps no per-turn
## tapped snapshot, so Rasputin keeps his own in card memory: a
## BECAME_TAPPED trigger raises the flag, a BECAME_UNTAPPED trigger lowers
## it. The untap step's own untap is dispatched during the untap step,
## which has no priority (CR 502.4), so that bookkeeping trigger sits
## UNDER the upkeep trigger on the stack and resolves after it — the
## upkeep check therefore still sees the flag as it stood when the turn
## began, and the flag clears itself immediately afterwards. (The engine
## fires no became-tapped event for a permanent that ENTERS tapped, which
## nothing in this pool can do to a creature; Kismet taps on arrival and
## so is seen.) The condition is deliberately NOT re-tested on resolution:
## "started the turn untapped" is a fact about the past, so tapping him in
## response to the trigger must not take the counter away.


func build() -> CardData:
	return CardData.new("Rasputin Dreamweaver", "{4}{W}{U}", Mtg.CardType.CREATURE) \
		.pt(4, 1) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.with_subtypes(["human", "wizard"]) \
		.with_enters_counters("dream", 7) \
		.mana(ManaAbility.new(Mtg.ManaColor.C).without_tap() \
			.with_counter_cost("dream", 1)) \
		.activated(ActivatedAbility.new("", false, [DreamShieldEffect.new()],
			"Remove a dream counter from Rasputin: Prevent the next 1 damage that would be dealt to Rasputin this turn.") \
			.with_counter_cost("dream", 1)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _refill,
			"At the beginning of your upkeep, if Rasputin started the turn untapped, put a dream counter on it.",
			_your_upkeep_untapped)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _remember_tapped,
			"Rasputin remembers being tapped.", _is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_UNTAPPED, _forget_tapped,
			"Rasputin remembers being untapped.", _is_self)) \
		.oracle("Rasputin enters with seven dream counters on it.\nRemove a dream counter from Rasputin: Add {C}.\nRemove a dream counter from Rasputin: Prevent the next 1 damage that would be dealt to Rasputin this turn.\nAt the beginning of your upkeep, if Rasputin started the turn untapped, put a dream counter on it.\nRasputin can't have more than seven dream counters on it.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _remember_tapped(_game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	source.memory["was_tapped"] = true


static func _forget_tapped(_game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	source.memory["was_tapped"] = false


## The intervening "if" (CR 603.4): your upkeep, and he began this turn
## untapped — the memory flag, not his state after the untap step.
static func _your_upkeep_untapped(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id \
		and not source.tapped \
		and not bool(source.memory.get("was_tapped", false))


static func _refill(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if int(source.counters.get("dream", 0)) >= 7:
		return   # "can't have more than seven dream counters on it"
	game.add_counters(source, "dream", 1)


class DreamShieldEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source != null and source.zone == Mtg.Zone.BATTLEFIELD:
			source.prevention += 1
			game.log_line("%s shields itself from the next 1 damage"
				% source.data.card_name)

	func describe() -> String:
		return "prevents the next 1 damage that would be dealt to Rasputin this turn"
