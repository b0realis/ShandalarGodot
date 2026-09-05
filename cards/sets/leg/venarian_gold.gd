extends CardScript
## Venarian Gold — {X}{U}{U} — Enchantment — Aura — (leg, common)
## Oracle: Enchant creature
##         When this Aura enters, tap enchanted creature and put X sleep
##         counters on it.
##         Enchanted creature doesn't untap during its controller's untap
##         step if it has a sleep counter on it.
##         At the beginning of the upkeep of enchanted creature's
##         controller, remove a sleep counter from that creature.
##
## Implementation: a scalable Paralyze. The sleep counters live on the
## CREATURE, not on the Aura, exactly as printed, and X comes off the
## card's own memory where MtgGame.cast_spell stamps it; the arrival
## trigger both taps the host and loads the counters.
##
## Read the second and third lines carefully — both of them say "ENCHANTED
## creature", so both are abilities OF THE AURA. Destroying the Gold
## therefore ends the untap lock at once (there is no enchanted creature
## any more) and stops the counters ticking down, even though the counters
## themselves stay on the creature; nothing else in this pool reads a sleep
## counter, so they simply sit there. That is the printed card, not a
## shortcut: this file used to carry a ledger row claiming the lock ought
## to survive the Aura, and the row was wrong (checked against the printed
## text 2026-09-01, lifted the same day).


func build() -> CardData:
	return CardData.new("Venarian Gold", "{X}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(
			_lock, "Enchanted creature doesn't untap during its controller's untap step if it has a sleep counter on it.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _put_to_sleep,
			"When this Aura enters, tap enchanted creature and put X sleep counters on it.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _wake_up,
			"At the beginning of the upkeep of enchanted creature's controller, remove a sleep counter from that creature.",
			_host_controllers_upkeep)) \
		.oracle("Enchant creature\n"
			+ "When this Aura enters, tap enchanted creature and put X sleep counters on it.\n"
			+ "Enchanted creature doesn't untap during its controller's untap step if it has "
			+ "a sleep counter on it.\n"
			+ "At the beginning of the upkeep of enchanted creature's controller, remove a "
			+ "sleep counter from that creature.")


static func _host_of(game: MtgGame, source: CardInstance) -> CardInstance:
	if source.attached_to == -1:
		return null
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return null
	return host


## "ENCHANTED creature doesn't untap ... if it has a sleep counter on it" —
## an ability of the Aura, so it holds only while the Aura does.
static func _lock(game: MtgGame, source: CardInstance) -> void:
	var host := _host_of(game, source)
	if host != null and int(host.counters.get("sleep", 0)) > 0:
		host.cur_skips_untap = true


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _put_to_sleep(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := _host_of(game, source)
	if host == null:
		return
	game.tap_permanent(host)
	var x := int(source.memory.get("x_value", 0))
	if x > 0:
		game.add_counters(host, "sleep", x)


static func _host_controllers_upkeep(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var host := _host_of(game, source)
	return host != null and host.controller_id == int(event.data["player"])


static func _wake_up(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var host := _host_of(game, source)
	if host == null or int(host.counters.get("sleep", 0)) <= 0:
		return
	game.add_counters(host, "sleep", -1)
