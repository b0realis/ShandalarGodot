extends CardScript
## Infinite Authority — {W}{W}{W} — Enchantment — Aura — (leg, rare)
## Oracle: Enchant creature
##         Whenever enchanted creature blocks or becomes blocked by a
##         creature with toughness 3 or less, destroy the other creature at
##         end of combat. At the beginning of the next end step, if that
##         creature was destroyed this way, put a +1/+1 counter on the first
##         creature.
##
## Implementation: a creature that eats small blockers and grows on them.
## The trigger fires per declared block PAIR (BLOCKED), matching whichever
## side the host is on, and only when the OTHER creature's live toughness
## is 3 or less — a Giant Growth in response saves it.
##
## "Destroy at end of combat" is a delayed END-OF-COMBAT action
## (MtgGame.schedule_end_of_combat_action) rather than the plain
## doom-at-end-of-combat queue, because the reward has to know whether the
## destruction actually HAPPENED: the action destroys the victim and, only
## if it really landed in a graveyard (regeneration and indestructible both
## say no), banks a counter in the Aura's memory for the end step to pay
## out. That is the printed "if that creature was destroyed this way".


func build() -> CardData:
	return CardData.new("Infinite Authority", "{W}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _condemn,
			"Whenever enchanted creature blocks or becomes blocked by a creature with toughness 3 or less, destroy the other creature at end of combat.",
			_small_creature_in_the_pair)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_STEP_START, _reward,
			"At the beginning of the next end step, if that creature was destroyed this way, put a +1/+1 counter on enchanted creature.",
			_something_was_destroyed)) \
		.oracle("Enchant creature\n"
			+ "Whenever enchanted creature blocks or becomes blocked by a creature with "
			+ "toughness 3 or less, destroy the other creature at end of combat. At the "
			+ "beginning of the next end step, if that creature was destroyed this way, put "
			+ "a +1/+1 counter on the first creature.")


static func _other_in_pair(source: CardInstance, event: GameEvent) -> CardInstance:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	if attacker != null and attacker.id == source.attached_to:
		return blocker
	if blocker != null and blocker.id == source.attached_to:
		return attacker
	return null


static func _small_creature_in_the_pair(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var other := _other_in_pair(source, event)
	return other != null and other.cur_toughness <= 3


static func _condemn(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var other := _other_in_pair(source, event)
	if other == null or other.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.schedule_end_of_combat_action(_execute.bind(other.id, source.id))


## Runs at the end-of-combat step, independent of the Aura that scheduled
## it (CR 603.7a) — which is why it re-finds both objects by id.
static func _execute(game: MtgGame, victim_id: int, aura_id: int) -> void:
	var victim := game.find_instance(victim_id)
	if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.destroy(victim)
	if victim.zone == Mtg.Zone.BATTLEFIELD:
		return   # regenerated or indestructible: not "destroyed this way"
	var aura := game.find_instance(aura_id)
	if aura == null or aura.zone != Mtg.Zone.BATTLEFIELD:
		return
	aura.memory["earned"] = int(aura.memory.get("earned", 0)) + 1


static func _something_was_destroyed(_game: MtgGame, source: CardInstance,
		_event: GameEvent) -> bool:
	return int(source.memory.get("earned", 0)) > 0


static func _reward(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var earned := int(source.memory.get("earned", 0))
	source.memory["earned"] = 0
	if earned <= 0 or source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.add_counters(host, "+1/+1", earned)
