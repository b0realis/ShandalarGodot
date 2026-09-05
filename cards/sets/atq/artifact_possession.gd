extends CardScript
## Artifact Possession — {2}{B} — Enchantment — Aura — (atq, common)
## Oracle: Enchant artifact
##         Whenever enchanted artifact becomes tapped or a player activates
##         an ability of enchanted artifact without {T} in its activation
##         cost, this Aura deals 2 damage to that artifact's controller.
##
## Implementation: the Warp Artifact aura shape with TWO triggers, one per
## printed clause — BECAME_TAPPED and (new, docs/mechanics.md)
## ABILITY_ACTIVATED. Both read the HOST from live attachment state and
## bill its CURRENT controller, so a Steal Artifact in between moves the
## damage with the artifact.
##
## The "without {T}" gate is what stops the two clauses double-dipping on a
## "{T}: ..." ability, whose activation taps the host and would otherwise
## trigger both — and it is the modern wording of the ruling the original
## shipped: *"Tapping an artifact as part of its activation cost will only
## cause Artifact Possession's ability to trigger once"* (Duel.hlp,
## Artifact Possession, Wizards of the Coast Rulings). The 1997 help text
## itself reads *"plays an ability of enchanted artifact requiring an
## activation cost or that artifact becomes tapped"*, which is the same
## outcome by a different route; we follow the oracle.
##
## Mana abilities count (CR 605.1a — a mana ability is an activated
## ability), so an enchanted Ashnod's Altar stings its controller for every
## creature it eats. A tapping mana ability is covered by the tap clause
## exactly like any other {T} ability.


func build() -> CardData:
	var artifact_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ARTIFACT))
	return CardData.new("Artifact Possession", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.enchants(artifact_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED, _sting,
			"Whenever enchanted artifact becomes tapped, Artifact Possession "
			+ "deals 2 damage to that artifact's controller.",
			_host_became_tapped)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ABILITY_ACTIVATED, _sting,
			"Whenever a player activates an ability of enchanted artifact "
			+ "without {T} in its activation cost, Artifact Possession deals "
			+ "2 damage to that artifact's controller.",
			_host_ability_without_tap)) \
		.oracle("Enchant artifact\nWhenever enchanted artifact becomes tapped or a "
			+ "player activates an ability of enchanted artifact without {T} in its "
			+ "activation cost, this Aura deals 2 damage to that artifact's controller.")


static func _host_became_tapped(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var inst: CardInstance = event.data.get("instance")
	return inst != null and source.attached_to == inst.id


static func _host_ability_without_tap(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	if bool(event.data.get("taps", false)):
		return false   # the tap clause already caught this one
	var inst: CardInstance = event.data.get("instance")
	return inst != null and source.attached_to == inst.id


static func _sting(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	# CR 608.2h — the trigger resolves even if the host has since left; the
	# controller it names is read from live state where there still is one,
	# and from the event otherwise.
	var inst: CardInstance = event.data.get("instance")
	if inst == null:
		return
	var victim: int = inst.controller_id if inst.zone == Mtg.Zone.BATTLEFIELD \
		else int(event.data.get("controller", inst.controller_id))
	game.deal_damage(source, TargetRef.player(victim), 2)
