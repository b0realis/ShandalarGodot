extends CardScript
## Deathgrip — {B}{B} — Enchantment — (2ed, uncommon)
## Oracle: {B}{B}: Counter target green spell.
##
## Implementation: a color-hoser enchantment with a repeatable activated
## CounterEffect restricted to GREEN spells (color from the mana cost).
## Activated at instant speed like every ability.


func build() -> CardData:
	return CardData.new("Deathgrip", "{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{B}{B}", false,
			[CounterEffect.new("target green spell", _is_green)],
			"{B}{B}: Counter target green spell.")) \
		.oracle("{B}{B}: Counter target green spell.")


static func _is_green(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.G) != 0
