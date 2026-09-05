extends CardScript
## Goblin Shrine — {1}{R}{R} — Enchantment — Aura — (drk, common)
## Oracle: Enchant land
##         As long as enchanted land is a basic Mountain, Goblin creatures
##         get +1/+0.
##         When this Aura leaves the battlefield, it deals 1 damage to each
##         Goblin creature.
##
## Implementation: Goblin Caves' conditional anthem in its aggressive half,
## plus the parting shot. The leave-trigger uses the engine's "a departing
## permanent hears its own trigger" dispatch (CR 603.6d): the Shrine is
## already in the graveyard when the trigger resolves, its printed identity
## restored, so the damage is dealt by a red source and a Goblin with
## protection from red still shrugs it off. The shot is UNCONDITIONAL — it
## does not care whether the host was a basic Mountain — and it hits every
## Goblin on the table, including the Shrine controller's own.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Goblin Shrine", "{1}{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.static_ability(StaticAbility.new(
			_muster, "As long as enchanted land is a basic Mountain, Goblin creatures get +1/+0.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.LEAVES_BATTLEFIELD, _collapse,
			"When this Aura leaves the battlefield, it deals 1 damage to each Goblin creature.",
			_it_left)) \
		.oracle("Enchant land\n"
			+ "As long as enchanted land is a basic Mountain, Goblin creatures get +1/+0.\n"
			+ "When this Aura leaves the battlefield, it deals 1 damage to each Goblin creature.")


## Is the host a BASIC MOUNTAIN right now? Supertype off the printed card
## (nothing in this pool grants "basic", and CR 305.7 retyping does not),
## subtype off the live list, which a Magical Hack can rewrite.
static func _on_a_basic_mountain(game: MtgGame, source: CardInstance) -> bool:
	if source.attached_to == -1:
		return false
	var host := game.find_instance(source.attached_to)
	return host != null and host.zone == Mtg.Zone.BATTLEFIELD \
		and (host.data.supertypes & Mtg.Supertype.BASIC) != 0 \
		and host.has_subtype("mountain")


static func _muster(game: MtgGame, source: CardInstance) -> void:
	if not _on_a_basic_mountain(game, source):
		return
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.has_subtype("goblin"):
			inst.cur_power += 1


static func _it_left(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["instance"] == source


static func _collapse(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var goblins: Array[CardInstance] = []
	for inst in game.all_battlefield():
		if inst.is_creature() and inst.has_subtype("goblin"):
			goblins.append(inst)
	for inst in goblins:
		game.deal_damage(source, TargetRef.card(inst), 1)
