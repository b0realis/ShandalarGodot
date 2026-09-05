extends CardScript
## Uncle Istvan — {1}{B}{B}{B} — Creature — Human — 1/3 — (4ed, uncommon)
## Oracle: Prevent all damage that would be dealt to this creature by
##         creatures.
##
## Implementation: a self-static raising cur_prevent_damage_from_creatures;
## MtgGame.deal_damage checks the flag against a LIVE is_creature() on the
## source — combat damage, Tim pings and Pestilence... no, Pestilence is
## an enchantment; its damage still lands. Bolts and Earthquakes too.


func build() -> CardData:
	return CardData.new("Uncle Istvan", "{1}{B}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 3) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(
			_stoic, "Prevent all damage that would be dealt to this creature by creatures.")) \
		.oracle("Prevent all damage that would be dealt to this creature by creatures.")


static func _stoic(_game: MtgGame, source: CardInstance) -> void:
	source.cur_prevent_damage_from_creatures = true
