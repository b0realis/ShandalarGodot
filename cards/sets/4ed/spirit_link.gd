extends CardScript
## Spirit Link — {W} — Enchantment — Aura — (4ed, uncommon)
## Oracle: Enchant creature (Target a creature as you cast this. This card
##         enters attached to that creature.)
##         Whenever enchanted creature deals damage, you gain that much life.
##
## Implementation: El-Hajjâj as an aura — the DAMAGE_DEALT trigger
## matches when the source is the HOST, and "you" is the AURA's
## controller: linking the opponent's fattie feeds you its damage.


func build() -> CardData:
	return CardData.new("Spirit Link", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _drink,
			"Whenever enchanted creature deals damage, you gain that much life.",
			_dealt_by_host)) \
		.oracle("Enchant creature\nWhenever enchanted creature deals damage, you gain that much life.")


static func _dealt_by_host(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return source.attached_to != -1 \
		and event.data["source"] is CardInstance \
		and (event.data["source"] as CardInstance).id == source.attached_to


static func _drink(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.adjust_life(source.controller_id, event.data["amount"])
