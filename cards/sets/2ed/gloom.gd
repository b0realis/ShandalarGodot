extends CardScript
## Gloom — {2}{B} — Enchantment — (2ed, uncommon)
## Oracle: White spells cost {3} more to cast.
##         Activated abilities of white enchantments cost {3} more to activate.
##
## Implementation: the engine's first COST MODIFIER (CardData.cost_modifier
## → MtgGame.spell_surcharge / ability_surcharge, summed at cast and
## activation time). Both taxes key off the COLOR derived from mana cost
## (CR 105.2); the ability tax additionally requires the source to be an
## enchantment. Black's classic hoser of the CoP decks Shandalar's white
## wizards lean on. The AI's mana planner calls the same surcharge helpers,
## so it prices Gloom in rather than bouncing casts off the engine.


func build() -> CardData:
	return CardData.new("Gloom", "{2}{B}", Mtg.CardType.ENCHANTMENT) \
		.with_cost_modifier(_tax_white_spell, _tax_white_enchantment_ability) \
		.oracle("White spells cost {3} more to cast.\nActivated abilities of white enchantments cost {3} more to activate.")


static func _tax_white_spell(_game: MtgGame, _caster: int, data: CardData,
		_source: CardInstance) -> int:
	return 3 if (data.color_mask() & Mtg.ManaColor.W) != 0 else 0


static func _tax_white_enchantment_ability(_game: MtgGame, _caster: int,
		source: CardInstance, _modifier: CardInstance) -> int:
	if not source.is_type(Mtg.CardType.ENCHANTMENT):
		return 0
	return 3 if (source.cur_colors & Mtg.ManaColor.W) != 0 else 0
