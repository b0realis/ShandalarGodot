extends CardScript
## Enchanted Being — {1}{W}{W} — Creature — Human — 2/2 — (leg, common)
## Oracle: Prevent all combat damage that would be dealt to this creature
##         by enchanted creatures.
##
## Implementation: a source-filtered damage immunity (Wall of Putrid
## Flesh's mechanism) whose predicate accepts any creature carrying an
## attachment, flagged COMBAT-ONLY: the printed card, `Cards.dat` and
## `legends.c` (`combat_damage_being_prevented`) all agree, so an
## enchanted Prodigal Sorcerer still pings it. A 2/2 that walls out the
## entire aura deck.


func build() -> CardData:
	return CardData.new("Enchanted Being", "{1}{W}{W}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human"]) \
		.static_ability(StaticAbility.new(
			_apply,
			"Prevent all combat damage that would be dealt to Enchanted Being by "
			+ "enchanted creatures.")) \
		.oracle("Prevent all combat damage that would be dealt to this creature by "
			+ "enchanted creatures.")


static func _is_enchanted(_game: MtgGame, damager: CardInstance) -> bool:
	return damager.is_creature() and not damager.attachments.is_empty()


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_damage_immunity.append(
		{"desc": "enchanted creatures", "filter": _is_enchanted, "combat": true})
