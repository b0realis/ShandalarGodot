extends CardScript
## Haunting Wind — {3}{B} — Enchantment — (atq, uncommon)
## Oracle: Whenever an artifact becomes tapped or a player activates an
##         artifact's ability without {T} in its activation cost, this
##         enchantment deals 1 damage to that artifact's controller.
##
## Implementation: Powerleech's pair of triggers without the "opponent"
## gate — the Wind is symmetric and stings its own controller too. The
## damage goes to the ARTIFACT's controller, never the activator, which is
## the only place the two differ when someone reaches across the table.
##
## The "without {T}" gate keeps a "{T}: ..." ability to ONE trigger, via
## the tap clause — the modern wording of the ruling the original shipped:
## *"Tapping an artifact as part of its activation cost will only cause
## Haunting Wind's ability to trigger once"* (Duel.hlp, Haunting Wind,
## Wizards of the Coast Rulings).


func build() -> CardData:
	return CardData.new("Haunting Wind", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _sting,
			"Whenever an artifact becomes tapped, Haunting Wind deals 1 damage to "
			+ "that artifact's controller.",
			_is_artifact)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ABILITY_ACTIVATED, _sting,
			"Whenever a player activates an artifact's ability without {T} in its "
			+ "activation cost, Haunting Wind deals 1 damage to that artifact's "
			+ "controller.",
			_is_artifact_ability)) \
		.oracle("Whenever an artifact becomes tapped or a player activates an "
			+ "artifact's ability without {T} in its activation cost, this enchantment "
			+ "deals 1 damage to that artifact's controller.")


static func _is_artifact(_game: MtgGame, _source: CardInstance,
		event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.is_type(Mtg.CardType.ARTIFACT)


static func _is_artifact_ability(_game: MtgGame, _source: CardInstance,
		event: GameEvent) -> bool:
	if bool(event.data.get("taps", false)):
		return false   # the tap clause already caught this one
	var inst: CardInstance = event.data.get("instance")
	return inst != null and inst.is_type(Mtg.CardType.ARTIFACT)


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# CR 608.2h — the artifact may be gone by the time this resolves (its
	# own sacrifice cost); the event still names who controlled it.
	var inst: CardInstance = event.data["instance"]
	var victim: int = inst.controller_id if inst.zone == Mtg.Zone.BATTLEFIELD \
		else int(event.data.get("controller", inst.controller_id))
	game.deal_damage(source, TargetRef.player(victim), 1)

