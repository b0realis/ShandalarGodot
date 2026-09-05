extends CardScript
## Tawnos's Coffin — {4} — Artifact — (atq, rare)
## Oracle: You may choose not to untap this artifact during your untap step.
##         {3}, {T}: Exile target creature and all Auras attached to it.
##         Note the number and kind of counters that were on that creature.
##         When this artifact leaves the battlefield or becomes untapped,
##         return that exiled card to the battlefield under its owner's
##         control tapped with the noted number and kind of counters on it.
##         If you do, return the other exiled cards to the battlefield under
##         their owner's control attached to that permanent.
##
## Implementation: the Coffin remembers each exiled creature, its counters
## and the ids of its Auras as ONE RECORD PER ACTIVATION in its card-local
## memory ("prisoners", oldest first). The Auras are exiled BEFORE their
## host, so the orphaned-Aura state-based action (CR 704.5m) never sees
## them, and they come back attached to the creature through
## MtgGame.attach_aura_from_anywhere — a Control Magic that rode along
## re-takes the creature as it re-attaches. Both release conditions are
## covered: untapping (the untap step, or an Icy-style untap) and leaving
## the battlefield, the latter through the memory SNAPSHOT the engine
## hands to departing permanents.
##
## Why a list: each activation creates its own delayed trigger (CR 603.7)
## bound to its own exiled card. Re-activating the Coffin in RESPONSE to
## its own untap trigger (the Coffin is tapped again by the cost) must not
## overwrite the first prisoner's record — the untap trigger then releases
## the FIRST creature and the second stays in exile until the next untap,
## and the Coffin leaving the battlefield releases everyone. A delayed
## trigger fires only once (CR 603.7b), so a second untap while a release
## is still on the stack triggers nothing new: the condition counts this
## Coffin's release triggers already waiting. "buried" mirrors the oldest
## record's card for MtgGame._is_sustaining.
##
## "You may choose not to untap" is the controller's call, asked in their
## untap step (MtgGame._untap_step: "Untap Tawnos's Coffin." / "Don't
## untap."); the heuristic keeps it shut for exactly as long as it is
## sustaining an exiled creature (MtgGame._is_sustaining) and opens it
## otherwise — but a seat may keep it shut, or open it early.


func build() -> CardData:
	return CardData.new("Tawnos's Coffin", "{4}", Mtg.CardType.ARTIFACT) \
		.with_may_skip_untap() \
		.activated(ActivatedAbility.new("{3}", true,
			[EntombEffect.new(TargetSpec.creature())],
			"{3}, {T}: Exile target creature and all Auras attached to it.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _release_on_leaving,
			"When this artifact leaves the battlefield, return the exiled cards to the battlefield tapped.",
			_is_self_leaving)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_UNTAPPED, _release_on_untap,
			"When this artifact becomes untapped, return the exiled cards to the battlefield tapped.",
			_is_self_untapping)) \
		.oracle("You may choose not to untap this artifact during your untap step.\n{3}, {T}: Exile target creature and all Auras attached to it. Note the number and kind of counters that were on that creature. When this artifact leaves the battlefield or becomes untapped, return that exiled card to the battlefield under its owner's control tapped with the noted number and kind of counters on it. If you do, return the other exiled cards to the battlefield under their owner's control attached to that permanent.")


static func _is_self_leaving(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var parting: Dictionary = event.data.get("memory", {})
	return event.data.get("instance") == source \
		and not Array(parting.get("prisoners", [])).is_empty()


static func _is_self_untapping(game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if event.data.get("instance") != source:
		return false
	# One release per activation, and each fires ONCE (CR 603.7b): a
	# prisoner whose release is already on the stack does not trigger
	# again when the Coffin untaps a second time before it resolves.
	var prisoners: Array = source.memory.get("prisoners", [])
	return prisoners.size() > _releases_waiting(game, source)


## How many of this Coffin's untap releases are already on the stack.
static func _releases_waiting(game: MtgGame, source: CardInstance) -> int:
	var waiting := 0
	for item in game.stack:
		if item.kind == Mtg.StackKind.TRIGGER and item.card == source \
				and item.trigger != null \
				and item.trigger.event_type == Mtg.EventType.BECAME_UNTAPPED:
			waiting += 1
	return waiting


## Keep "buried" pointing at the oldest prisoner (MtgGame._is_sustaining
## reads it to keep the Coffin shut in the untap step), or drop it when
## the Coffin holds nobody.
static func _mirror_oldest(source: CardInstance) -> void:
	var prisoners: Array = source.memory.get("prisoners", [])
	if prisoners.is_empty():
		source.memory.erase("buried")
	else:
		source.memory["buried"] = int((prisoners[0] as Dictionary).get("buried", -1))


static func _release_on_untap(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	var prisoners: Array = source.memory.get("prisoners", [])
	if prisoners.is_empty():
		return
	# Oldest first: this is the release the earliest activation promised.
	var record: Dictionary = prisoners.pop_front()
	_mirror_oldest(source)
	_release(game, int(record.get("buried", -1)), record.get("counters", {}),
		Array(record.get("auras", [])))


static func _release_on_leaving(game: MtgGame, _source: CardInstance,
		event: GameEvent) -> void:
	var parting: Dictionary = event.data.get("memory", {})
	for record in Array(parting.get("prisoners", [])):
		var rec: Dictionary = record
		_release(game, int(rec.get("buried", -1)), rec.get("counters", {}),
			Array(rec.get("auras", [])))


## Put the buried creature back, tapped, with its noted counters — and, if
## it really did come back ("If you do"), its Auras on top of it.
static func _release(game: MtgGame, buried_id: int, counters: Dictionary,
		auras: Array) -> void:
	var buried := game.find_instance(buried_id)
	if buried == null or buried.zone != Mtg.Zone.EXILE:
		return
	game.return_from_exile_to_play(buried, buried.owner_id, true)
	for kind in counters:
		game.add_counters(buried, String(kind), int(counters[kind]))
	for aura_id in auras:
		var aura := game.find_instance(int(aura_id))
		if aura == null or aura.zone != Mtg.Zone.EXILE:
			continue
		# "under their owner's control attached to that permanent"
		game.attach_aura_from_anywhere(aura, buried, aura.owner_id)
		if aura.data.aura_steals:
			# Control Magic takes the creature again as it re-attaches
			# (the aura's own effect applies afresh, CR 613/303.4).
			game.change_control(buried, aura.controller_id)


class EntombEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		if source == null or source.zone != Mtg.Zone.BATTLEFIELD:
			return
		var victim := game.find_instance(target.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			return
		var counters: Dictionary = victim.counters.duplicate()
		# "and all Auras attached to it" — exiled FIRST, while their host is
		# still on the battlefield, so they never become orphans that the
		# state-based action sweeps into a graveyard (CR 704.5m). The list
		# is duplicated because exiling each one edits victim.attachments.
		var auras: Array = []
		for attachment_id in victim.attachments.duplicate():
			var attached := game.find_instance(int(attachment_id))
			if attached == null or attached.zone != Mtg.Zone.BATTLEFIELD:
				continue
			if not attached.data.is_aura():
				continue
			auras.append(attached.id)
			game.exile_permanent(attached)
		# One record per activation, appended behind any earlier prisoner
		# still waiting for its release (CR 603.7: each activation's own
		# delayed trigger).
		var prisoners: Array = source.memory.get("prisoners", [])
		prisoners.append({"buried": victim.id, "counters": counters, "auras": auras})
		source.memory["prisoners"] = prisoners
		# "buried" mirrors the OLDEST prisoner (see _mirror_oldest; an inner
		# class cannot call the script's statics unqualified).
		source.memory["buried"] = int((prisoners[0] as Dictionary).get("buried", -1))
		game.exile_permanent(victim)

	func describe() -> String:
		return "exiles target creature and its Auras until this artifact untaps or leaves"
