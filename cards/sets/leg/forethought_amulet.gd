extends CardScript
## Forethought Amulet — {5} — Artifact — (leg, rare)
## Oracle: At the beginning of your upkeep, sacrifice this artifact unless
##         you pay {3}.
##         If an instant or sorcery source would deal 3 or more damage to
##         you, it deals 2 damage to you instead.
##
## Implementation: the rent is the engine's usual "unless you pay" upkeep
## trigger. The cap is a REPLACEMENT effect on the seat
## (MtgPlayer.damage_caps, new), applied in MtgGame before any prevention —
## which matters, because a capped Fireball was never bigger than 2, so a
## Circle of Protection then only has 2 to eat and the packet records no
## prevention at all.
##
## "3 OR MORE" is the printed threshold, so a Lightning Bolt is capped to 2
## and a Shock is untouched. The source must be an instant or a sorcery, so
## combat damage, a Prodigal Sorcerer's ping and Ankh of Mishra all get
## through at full size — the Amulet answers burn, not the board.
##
## The static rebuilds the cap every recalculation, so the moment the Amulet
## is sacrificed for the rent the cap is gone.


func build() -> CardData:
	return CardData.new("Forethought Amulet", "{5}", Mtg.CardType.ARTIFACT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, sacrifice this artifact unless you pay {3}.",
			_your_upkeep)) \
		.static_ability(StaticAbility.new(
			_cap, "If an instant or sorcery source would deal 3 or more damage to you, it deals 2 damage to you instead.")) \
		.oracle("At the beginning of your upkeep, sacrifice this artifact unless you "
			+ "pay {3}.\nIf an instant or sorcery source would deal 3 or more damage "
			+ "to you, it deals 2 damage to you instead.")


static func _your_upkeep(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _pay_the_rent(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var rent := ManaCost.parse("{3}")
	var pid := source.controller_id
	if game.can_afford_cost(pid, rent) and game.agents[pid].choose_yes_no(
			game, pid, "Pay {3} to keep Forethought Amulet?", true) \
			and game.try_pay(pid, rent):
		return
	game.sacrifice_permanent(source)


static func _cap(game: MtgGame, source: CardInstance) -> void:
	game.players[source.controller_id].damage_caps.append({
		"desc": "Forethought Amulet",
		"filter": _is_a_spell,
		"threshold": 3,
		"becomes": 2,
	})


## An INSTANT or SORCERY source. A resolving spell is still on the stack
## while it deals its damage, so the printed "source" is exactly the card
## the engine hands the damage helper.
static func _is_a_spell(_game: MtgGame, damage_source: CardInstance) -> bool:
	return damage_source.data.is_type(Mtg.CardType.INSTANT) \
		or damage_source.data.is_type(Mtg.CardType.SORCERY)
