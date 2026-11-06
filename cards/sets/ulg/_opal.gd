extends RefCounted
## Urza's Legacy (_opal, Pack 10). Enchantments that become creatures — Opal
## Avenger, Opal Champion, Lurking Skirge, Hidden Gibbons — on the shared
## helpers of cards/sets/usg/_opal.gd (its header has the rules: the card
## type REPLACED, CR 205.1a; the intervening "if this permanent is an
## enchantment", CR 603.4; state triggers, CR 603.8).
## tests/cards/test_pack_10_B12_*.gd pin each card.

const O := preload("res://cards/sets/usg/_opal.gd")


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Opal Avenger":
			O.becomes(c, Mtg.EventType.STATE_CHECK, O.you_have_ten_or_less,
				"When you have 10 or less life, if this permanent is an enchantment, it becomes a 3/5 Soldier creature.",
				3, 5, ["soldier"])
		"Opal Champion":
			O.becomes(c, Mtg.EventType.SPELL_CAST, O.opponent_casts.bind(Mtg.CardType.CREATURE),
				"When an opponent casts a creature spell, if this permanent is an enchantment, it becomes a 3/3 Knight creature with first strike.",
				3, 3, ["knight"], [Mtg.Keyword.FIRST_STRIKE])
		"Lurking Skirge":
			O.becomes(c, Mtg.EventType.DIES, O.creature_to_opponents_graveyard,
				"When a creature is put into an opponent's graveyard from the battlefield, if this permanent is an enchantment, it becomes a 3/2 Phyrexian Imp creature with flying.",
				3, 2, ["phyrexian", "imp"], [Mtg.Keyword.FLYING])
		"Hidden Gibbons":
			O.becomes(c, Mtg.EventType.SPELL_CAST, O.opponent_casts.bind(Mtg.CardType.INSTANT),
				"When an opponent casts an instant spell, if this permanent is an enchantment, it becomes a 4/4 Ape creature.",
				4, 4, ["ape"])
		_: return false
	return true
