extends CardScript
## Living Artifact — {G} — Enchantment — Aura — (2ed, rare)
## Oracle: Enchant artifact
##         Whenever you're dealt damage, put that many vitality counters on
##         this Aura.
##         At the beginning of your upkeep, you may remove a vitality
##         counter from this Aura. If you do, you gain 1 life.
##
## Implementation: a damage battery. The charge trigger listens on
## DAMAGE_DEALT and matches only events whose "to_player" key is the AURA's
## controller — damage to your creatures charges nothing, and neither does
## damage the opponent takes. The amount comes off the EVENT (CR 603.1), so
## a bolt that was partly prevented banks only what actually landed. The
## discharge is one counter, one life, once per upkeep, and it is optional.
##
## The host does nothing at all: the artifact is only a place to hang the
## Aura, which is why the Aura dies with it.


func build() -> CardData:
	var artifact_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ARTIFACT))
	return CardData.new("Living Artifact", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(artifact_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _charge,
			"Whenever you're dealt damage, put that many vitality counters on this Aura.",
			_damage_to_controller)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _discharge,
			"At the beginning of your upkeep, you may remove a vitality counter from this Aura. If you do, you gain 1 life.",
			_own_upkeep)) \
		.oracle("Enchant artifact\n"
			+ "Whenever you're dealt damage, put that many vitality counters on this Aura.\n"
			+ "At the beginning of your upkeep, you may remove a vitality counter from this "
			+ "Aura. If you do, you gain 1 life.")


static func _damage_to_controller(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.has("to_player") \
		and int(event.data["to_player"]) == source.controller_id


static func _charge(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.add_counters(source, "vitality", int(event.data["amount"]))


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _discharge(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	if int(source.counters.get("vitality", 0)) <= 0:
		return
	var pid := int(event.data["player"])
	if not game.agents[pid].choose_yes_no(game, pid,
			"Spend a vitality counter from %s for 1 life?" % source.data.card_name, true):
		return
	game.add_counters(source, "vitality", -1)
	game.adjust_life(pid, 1)
