extends CardScript
## Venom — {1}{G}{G} — Enchantment — Aura — (4ed, common)
## Oracle: Enchant creature
##         Whenever enchanted creature blocks or becomes blocked by a
##         non-Wall creature, destroy the other creature at end of combat.
##
## Implementation: the basilisk gaze as an aura (thicket_basilisk.gd) —
## the HOST plays the basilisk's role; the trigger lives on the aura and
## dooms the other, non-Wall creature via the end-of-combat queue.


func build() -> CardData:
	return CardData.new("Venom", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gaze,
			"Whenever enchanted creature blocks or becomes blocked by a non-Wall creature, destroy the other creature at end of combat.",
			_host_meets_non_wall)) \
		.oracle("Enchant creature\nWhenever enchanted creature blocks or becomes blocked by a non-Wall creature, destroy the other creature at end of combat.")


static func _other_of_host(source: CardInstance, event: GameEvent) -> CardInstance:
	if source.attached_to == -1:
		return null
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	if attacker != null and attacker.id == source.attached_to:
		return blocker
	if blocker != null and blocker.id == source.attached_to:
		return attacker
	return null


static func _host_meets_non_wall(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var other := _other_of_host(source, event)
	return other != null and not other.has_subtype("wall")


static func _gaze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var other := _other_of_host(source, event)
	if other != null and other.zone == Mtg.Zone.BATTLEFIELD:
		game.doom_at_end_of_combat(other)
