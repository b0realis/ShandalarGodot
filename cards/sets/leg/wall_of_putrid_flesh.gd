extends CardScript
## Wall of Putrid Flesh — {2}{B} — Creature — Wall — 2/4 — (leg, uncommon)
## Oracle: Defender (This creature can't attack.)
##         Protection from white
##         Prevent all damage that would be dealt to this creature by
##         enchanted creatures.
##
## Implementation: printed protection from white (the full DEBT bundle —
## Swords to Plowshares can't even target it) plus a source-filtered
## damage immunity whose predicate asks whether the damage source carries
## any attachment. A 2/4 wall that walls out white AND the aura decks.


func build() -> CardData:
	return CardData.new("Wall of Putrid Flesh", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["wall"]) \
		.with_keywords([Mtg.Keyword.DEFENDER]) \
		.with_protection_from(Mtg.ManaColor.W) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all damage that would be dealt to Wall of Putrid Flesh by "
			+ "enchanted creatures.")) \
		.oracle("Defender (This creature can't attack.)\nProtection from white\n"
			+ "Prevent all damage that would be dealt to this creature by enchanted "
			+ "creatures.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_immunity.append(
		{"desc": "enchanted creatures", "filter": _is_enchanted})


static func _is_enchanted(_game: MtgGame, damager: CardInstance) -> bool:
	return damager.is_creature() and not damager.attachments.is_empty()
