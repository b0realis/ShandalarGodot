extends CardScript
## Gem Bazaar — Land — (past, common)
## Oracle: When Gem Bazaar comes into play, choose a random color.
##         {T}: Add to your mana pool one mana of the color last chosen.
##         Then choose a random color.
##
## Implementation: the chosen colour lives in the land's own
## CardInstance.memory; the mana ability reads it through
## ManaAbility.with_dynamic_color and rerolls it as a side effect, so the
## colour you get is always the one you could see before tapping.


func build() -> CardData:
	return CardData.new("Gem Bazaar", "", Mtg.CardType.LAND) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose_on_entry,
			"When Gem Bazaar comes into play, choose a random color.",
			_is_self)) \
		.mana(ManaAbility.new(Mtg.ManaColor.W) \
			.with_dynamic_color(_chosen_color) \
			.with_side_effect(_reroll)) \
		.oracle("When Gem Bazaar comes into play, choose a random color.\n{T}: Add to your mana pool one mana of the color last chosen. Then choose a random color.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose_on_entry(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory["color"] = RandomEffects.color(game)


static func _chosen_color(game: MtgGame, source: CardInstance) -> int:
	if not source.memory.has("color"):
		source.memory["color"] = RandomEffects.color(game)
	return int(source.memory["color"])


static func _reroll(game: MtgGame, source: CardInstance, _controller: int) -> void:
	source.memory["color"] = RandomEffects.color(game)
