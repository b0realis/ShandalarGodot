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
## say no), creates the reward as a DELAYED TRIGGER for the next end step
## (MtgGame.schedule_delayed_trigger). That is the printed "if that
## creature was destroyed this way".
##
## None of it needs the Aura once the block trigger has fired (CR 603.6,
## 603.7a — 2026-10-03): the pair is captured as the trigger goes on the
## stack, so an Aura destroyed in response still condemns the blocker, and
## "the first creature" is the creature it enchanted THEN — it gets its
## counter even if the Aura is gone by the end step. The reward used to be
## banked in the Aura's memory and paid by the Aura's own end-step trigger,
## so destroying the Aura after combat cancelled it.


func build() -> CardData:
	return CardData.new("Infinite Authority", "{W}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _condemn,
			"Whenever enchanted creature blocks or becomes blocked by a creature with toughness 3 or less, destroy the other creature at end of combat.",
			_small_creature_in_the_pair).capturing(_the_pair)) \
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


## The pair as the trigger goes on the stack: the enchanted creature ("the
## first creature") and the other one, each with its timestamp, so the
## trigger can resolve — and the reward land — without the Aura.
static func _the_pair(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> Dictionary:
	var other := _other_in_pair(source, event)
	var host: CardInstance = event.data["blocker"] if other == event.data["attacker"] \
		else event.data["attacker"]
	if other == null or host == null:
		return {}
	return {"host": host.id, "host_stamp": host.layer_timestamp,
		"other": other.id, "other_stamp": other.layer_timestamp}


static func _condemn(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var pair := game.trigger_context(source)
	var other := game.find_instance(int(pair.get("other", -1)))
	if other == null or other.zone != Mtg.Zone.BATTLEFIELD \
			or other.layer_timestamp != int(pair.get("other_stamp", -1)):
		return
	var pid := game.current_resolution_controller()
	if pid < 0:
		pid = source.controller_id
	game.schedule_end_of_combat_action(_execute.bind(other.id, source.id,
		int(pair.get("host", -1)), int(pair.get("host_stamp", -1)), pid))


## Runs at the end-of-combat step, independent of the Aura that scheduled
## it (CR 603.7a) — which is why it re-finds the victim by id.
static func _execute(game: MtgGame, victim_id: int, aura_id: int,
		host_id: int, host_stamp: int, pid: int) -> void:
	var victim := game.find_instance(victim_id)
	if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.destroy(victim)
	if victim.zone == Mtg.Zone.BATTLEFIELD:
		return   # regenerated or indestructible: not "destroyed this way"
	var aura := game.find_instance(aura_id)   # the card, wherever it is now
	if aura == null:
		return
	game.schedule_delayed_trigger(TriggeredAbility.new(
		Mtg.EventType.END_STEP_START, _reward.bind(host_id, host_stamp),
		"At the beginning of the next end step, put a +1/+1 counter on the first creature."),
		pid, aura)


static func _reward(game: MtgGame, _source: CardInstance, _event: GameEvent,
		host_id: int, host_stamp: int) -> void:
	var host := game.find_instance(host_id)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD \
			or host.layer_timestamp != host_stamp:
		return
	game.add_counters(host, "+1/+1", 1)
