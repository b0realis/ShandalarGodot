extends RefCounted
## Urza's Destiny (_opal, Pack 10). Opalescence and Lurking Jackals, on the
## shared helpers of cards/sets/usg/_opal.gd.
##
## - OPALESCENCE prints two statics, one per layer, as one effect. The
##   creature type is layer 4 and decides by CARD TYPE whom it applies to
##   ([method StaticAbility.reading_card_types]): an Opal that "becomes a 2/2
##   Soldier creature" is no enchantment any more, and a creature that Soul
##   Sculptor or Opal Acrolith's {0} made an enchantment is one — every such
##   type change applies first, whatever the timestamps (CR 613.8a). The
##   size is a layer-7b set at Opalescence's timestamp. Both carry the key
##   "opalescence" ([method StaticAbility.part_of], CR 613.6): with a second
##   Opalescence making this one a creature and a Humility silencing it, it
##   still sizes what it animated — the rules' own Humility pair: Humility
##   older, Humility is a 4/4 and every other creature 1/1; Humility newer,
##   every creature is 1/1.
## - "Non-Aura" is read live: a licid that became an Aura is excluded while
##   it is one; an enchantment of mana value 0 is a 0/0 and dies.
## - Lurking Jackals' "when an opponent has 10 or less life" is a state
##   trigger (CR 603.8).
## tests/cards/test_pack_10_B12_*.gd pin each card.

const O := preload("res://cards/sets/usg/_opal.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Opalescence":
			c.static_ability(StaticAbility.new(_opalesce,
				"Each other non-Aura enchantment is a creature in addition to its other types.") \
				.reading_card_types().part_of(&"opalescence"))
			c.static_ability(StaticAbility.new(_opal_size,
				"Each other non-Aura enchantment has base power and base toughness each equal to its mana value.") \
				.setting_base_pt().part_of(&"opalescence"))
		"Lurking Jackals":
			O.becomes(c, Mtg.EventType.STATE_CHECK, O.opponent_has_ten_or_less,
				"When an opponent has 10 or less life, if this permanent is an enchantment, it becomes a 3/2 Jackal creature.",
				3, 2, ["jackal"])
		_: return false
	return true


## "Each other non-Aura enchantment" — live types, both seats', not phased out.
static func animated_by(source: CardInstance, inst: CardInstance) -> bool:
	return inst != source and not inst.phased_out \
		and inst.is_type(Mtg.CardType.ENCHANTMENT) and not inst.has_subtype("aura")


## Layer 4: "... is a creature in addition to its other types."
static func _opalesce(g: MtgGame, source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if animated_by(source, inst):
			inst.cur_types |= Mtg.CardType.CREATURE


## Layer 7b: "... has base power and base toughness each equal to its mana
## value" — the same set (the types settled in layer 4; CR 613.6).
static func _opal_size(g: MtgGame, source: CardInstance) -> void:
	for inst in g.all_battlefield():
		if animated_by(source, inst):
			var size := inst.data.cost.mana_value()
			inst.cur_power = size
			inst.cur_toughness = size
