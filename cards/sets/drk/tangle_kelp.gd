extends CardScript
## Tangle Kelp — {U} — Enchantment — Aura — (drk, uncommon)
## Oracle: Enchant creature
##         When this Aura enters, tap enchanted creature.
##         Enchanted creature doesn't untap during its controller's untap
##         step if it attacked during its controller's last turn.
##
## Implementation: a one-mana tapper that then punishes attacking. The
## untap denial is Goblin Rock Sled's mechanism seen from the Aura's side:
## an END_STEP_START trigger on the host's controller's turn converts "it
## attacked this turn" into the engine's one-shot
## CardInstance.skip_next_untap, which their NEXT untap step consumes.
## Reading the flag at the end step is what makes "during its controller's
## LAST turn" exact — the engine clears attacked_this_turn at each untap
## step, so it cannot be read later.


func build() -> CardData:
	return CardData.new("Tangle Kelp", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _entangle,
			"When this Aura enters, tap enchanted creature.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _hold_it_down,
			"Enchanted creature doesn't untap during its controller's untap step if it attacked during its controller's last turn.",
			_host_attacked_this_turn)) \
		.oracle("Enchant creature\n"
			+ "When this Aura enters, tap enchanted creature.\n"
			+ "Enchanted creature doesn't untap during its controller's untap step if it "
			+ "attacked during its controller's last turn.")


static func _host_of(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _entangle(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := _host_of(game, source)
	if host != null:
		game.tap_permanent(host)


static func _host_attacked_this_turn(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var host := _host_of(game, source)
	return host != null and host.attacked_this_turn \
		and host.controller_id == int(event.data["player"])


static func _hold_it_down(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := _host_of(game, source)
	if host != null:
		host.skip_next_untap = true
