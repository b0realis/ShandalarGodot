extends CardScript
## Necropolis of Azar — {2}{B}{B} — Enchantment — (past, common)
## Oracle: Whenever a non-black creature is put into any graveyard from
##         play, put a husk counter on Necropolis of Azar.
##         {5}, Remove a husk counter from Necropolis of Azar: Put a Spawn
##         of Azar token into play. Treat this token as a black creature
##         with a random power and toughness, each no less than 1 and no
##         greater than 3, that has swampwalk.
##
## Implementation: husk counters are a plain (non-P/T) counter kind, so the
## continuous pipeline ignores them. "Remove a husk counter" is part of the
## ACTIVATION COST (CR 601.2h), declared with .with_counter_cost, so two
## activations can never be paid for with the same counter — activating
## with an empty Necropolis is refused instead of resolving into nothing.
## The token's P/T is rolled at creation and baked into a fresh CardData —
## two Spawns from the same Necropolis can be different sizes, as printed.
##
## "Non-black creature" is LAST KNOWN INFORMATION (CR 608.2h): the colour
## and the types the corpse had on the battlefield, not what is printed on
## it. The zone change wipes cur_* before the trigger condition runs, so
## the card reads CardInstance.last_colors / last_types, which the zone
## change snapshots for exactly this purpose — a Deathlaced (black) bear
## dying feeds nothing, and an animated Mishra's Factory does.


func build() -> CardData:
	return CardData.new("Necropolis of Azar", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _add_husk,
			"Whenever a non-black creature is put into any graveyard from play, put a husk counter on Necropolis of Azar.",
			_non_black_creature)) \
		.activated(ActivatedAbility.new("{5}", false, [SpawnEffect.new()],
			"{5}, Remove a husk counter: Put a Spawn of Azar token into play.") \
			.with_counter_cost("husk", 1).only_if(_has_husk)) \
		.oracle("Whenever a non-black creature is put into any graveyard from play, put a husk counter on Necropolis of Azar.\n{5}, Remove a husk counter from Necropolis of Azar: Put a Spawn of Azar token into play. Treat this token as a black creature with a random power and toughness, each no less than 1 and no greater than 3, that has swampwalk.")


static func _non_black_creature(_game: MtgGame, _source: CardInstance, event: GameEvent) -> bool:
	# LAST KNOWN INFORMATION (CR 608.2h): what it WAS as it left the
	# battlefield, which the zone change snapshots — cur_* is already back
	# at printed values by the time a dies-trigger condition runs.
	var dead: CardInstance = event.data["instance"]
	return (dead.last_types & Mtg.CardType.CREATURE) != 0 \
		and (dead.last_colors & Mtg.ManaColor.B) == 0


static func _add_husk(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone == Mtg.Zone.BATTLEFIELD:
		game.add_counters(source, "husk", 1)


## The counter cost already makes a counterless activation illegal; this
## states the same requirement one step earlier (before the mana check),
## so the refusal a player or the AI sees names the missing husk instead
## of the mana they were never going to spend.
static func _has_husk(_game: MtgGame, source: CardInstance) -> String:
	if int(source.counters.get("husk", 0)) <= 0:
		return "no husk counter to remove"
	return ""


class SpawnEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		# The husk counter was already spent as a COST — nothing to pay
		# here, and the Spawn arrives even if the Necropolis has since left.
		if source == null:
			return
		var power := RandomEffects.roll(game, 3) + 1
		var toughness := RandomEffects.roll(game, 3) + 1
		var token := CardData.new("Spawn of Azar", "", Mtg.CardType.CREATURE) \
			.with_colors(Mtg.ManaColor.B) \
			.pt(power, toughness) \
			.with_subtypes(["spawn"]) \
			.with_landwalk(["swamp"]) \
			.oracle("")
		game.create_token(controller, token)

	func describe() -> String:
		return "puts a Spawn of Azar token onto the battlefield"
