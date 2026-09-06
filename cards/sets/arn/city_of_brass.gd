extends CardScript
## City of Brass — Land (arn, rare)
## Oracle: Whenever City of Brass becomes tapped, it deals 1 damage to you.
##         {T}: Add one mana of any color.
##
## Implementation: five ManaAbility options (any color, like Birds of
## Paradise) + a BECAME_TAPPED trigger on ITSELF dealing 1 to its
## controller — ANY tap fires it: for mana, or an Icy Manipulator's
## effect. This is a NORMAL (stacked) trigger, not a mana trigger — the
## damage happens after the mana is in the pool, matching the card's
## play pattern. `.hurting(1)` on each option is for the mana planner
## only ([member ManaAbility.pain]): the engine deals the damage through
## the trigger, the planner just knows the tap is not free.


func build() -> CardData:
	return CardData.new("City of Brass", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).hurting(1)) \
		.mana(ManaAbility.new(Mtg.ManaColor.U).hurting(1)) \
		.mana(ManaAbility.new(Mtg.ManaColor.B).hurting(1)) \
		.mana(ManaAbility.new(Mtg.ManaColor.R).hurting(1)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G).hurting(1)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BECAME_TAPPED,
			_self_burn,
			"Whenever City of Brass becomes tapped, it deals 1 damage to you.",
			_is_self)) \
		.oracle("Whenever City of Brass becomes tapped, it deals 1 damage to you.\n{T}: Add one mana of any color.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["instance"] == source


static func _self_burn(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(source.controller_id), 1)
