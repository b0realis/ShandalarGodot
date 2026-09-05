extends CardScript
## Unstable Mutation — {U} — Enchantment — Aura (4ed, common; first printed in Arabian Nights)
## Oracle: Enchant creature. Enchanted creature gets +3/+3.
##         At the beginning of the upkeep of enchanted creature's
##         controller, put a -1/-1 counter on that creature.
##
## Implementation: the Faustian aura — static +3/+3 plus an upkeep trigger
## stacking permanent -1/-1 counters on the host. Turns 1-3 it's the best
## pump in the pool; by turn 4 the loan is called in and the counters (which
## OUTLIVE the aura, unlike the bonus) start killing. Counters + aura +
## upkeep trigger in one card — a fine machinery workout.


func build() -> CardData:
	return CardData.new("Unstable Mutation", "{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_apply, "Enchanted creature gets +3/+3.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _decay,
			"At the beginning of the upkeep of enchanted creature's controller, put a -1/-1 counter on that creature.",
			_is_host_controllers_upkeep)) \
		.oracle("Enchant creature. Enchanted creature gets +3/+3.\nAt the beginning of the upkeep of enchanted creature's controller, put a -1/-1 counter on that creature.")


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += 3
		host.cur_toughness += 3


static func _is_host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and host.controller_id == event.data["player"]


static func _decay(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(host, "-1/-1", 1)
