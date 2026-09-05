extends CardScript
## Lifeforce — {G}{G} — Enchantment — (2ed, uncommon)
## Oracle: {G}{G}: Counter target black spell.
##
## Implementation: Deathgrip's mirror — green's repeatable counter for
## BLACK spells only.


func build() -> CardData:
	return CardData.new("Lifeforce", "{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new(
			"{G}{G}", false,
			[CounterEffect.new("target black spell", _is_black)],
			"{G}{G}: Counter target black spell.")) \
		.oracle("{G}{G}: Counter target black spell.")


static func _is_black(inst: CardInstance) -> bool:
	return (inst.cur_colors & Mtg.ManaColor.B) != 0
