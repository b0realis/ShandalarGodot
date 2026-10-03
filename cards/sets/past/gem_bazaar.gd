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
##
## The colour reader is a QUERY — the mana planner asks it of every source
## whenever anybody wonders what they could pay — so it must not choose
## anything (2026-10-03): until then a Bazaar asked before its ETB had
## resolved rolled a colour on the spot, writing memory and drawing from
## MtgGame.rng, and so whether the AI had LOOKED changed the game. Before
## any colour has been chosen there is no "color last chosen" and tapping
## adds nothing (the dynamic amount is 0) — then chooses one, as printed.


func build() -> CardData:
	return CardData.new("Gem Bazaar", "", Mtg.CardType.LAND) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose_on_entry,
			"When Gem Bazaar comes into play, choose a random color.",
			_is_self)) \
		.mana(ManaAbility.new(Mtg.ManaColor.W) \
			.with_dynamic_color(_chosen_color) \
			.with_dynamic_amount(_amount) \
			.with_side_effect(_reroll)) \
		.oracle("When Gem Bazaar comes into play, choose a random color.\n{T}: Add to your mana pool one mana of the color last chosen. Then choose a random color.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose_on_entry(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory["color"] = RandomEffects.color(game)


## Side-effect free. White stands in when nothing is chosen yet — the
## amount is 0 then, so it is never produced.
static func _chosen_color(_game: MtgGame, source: CardInstance) -> int:
	return int(source.memory.get("color", Mtg.ManaColor.W))


static func _amount(_game: MtgGame, source: CardInstance) -> int:
	return 1 if source.memory.has("color") else 0


static func _reroll(game: MtgGame, source: CardInstance, _controller: int) -> void:
	source.memory["color"] = RandomEffects.color(game)
