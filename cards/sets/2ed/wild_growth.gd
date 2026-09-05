extends CardScript
## Wild Growth — {G} — Enchantment — Aura (2ed, common)
## Oracle: Enchant land. Whenever enchanted land is tapped for mana, its
##         controller adds an additional {G}.
##
## Implementation: an aura ON A LAND (the aura spec accepts any land) whose
## payload is a MANA TRIGGER (off-stack, CR 605.1b) conditioned on the
## tapped land being its host. Pairs with mana_flare.gd as the two mana
## triggers of the pool; the host check is the interesting part here.


func build() -> CardData:
	var land_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land",
		func(inst: CardInstance) -> bool: return inst.is_land())
	return CardData.new("Wild Growth", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(land_spec) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.TAPPED_FOR_MANA,
			_bonus_green,
			"Whenever enchanted land is tapped for mana, its controller adds an additional {G}.",
			_is_my_host).as_mana_trigger()) \
		.oracle("Enchant land.\nWhenever enchanted land is tapped for mana, its controller adds an additional {G}.")


static func _is_my_host(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return source.attached_to != -1 \
		and event.data["instance"].id == source.attached_to


static func _bonus_green(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	var pid: int = event.data["controller"]
	game.players[pid].mana_pool.add(Mtg.ManaColor.G, 1)
	game.log_line("Wild Growth adds an additional {G}")
