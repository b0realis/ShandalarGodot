extends CardScript
## Phantasmal Terrain — {U}{U} — Enchantment — Aura — (2ed, common)
## Oracle: Enchant land
##         As this Aura enters, choose a basic land type.
##         Enchanted land is the chosen type.
##
## Implementation: Evil Presence with a chosen type. The choice is made as
## the aura enters and remembered in CardInstance.memory (which the engine
## clears when the aura leaves the battlefield), then applied by the same
## become_basic_land_type static.
##
## "As this Aura enters, choose a basic land type" is the CASTER's choice,
## asked through their DecisionAgent on the arrival trigger — which is
## where it has to be asked, because an Aura's `attached_to` is only set
## after it is on the battlefield, and the static below runs on every
## recalculation and must never ask anything. Until that trigger resolves
## the static falls back to the hint (the type the host's controller has
## fewest of) WITHOUT caching it, so the player's answer still lands.


const TYPES := ["plains", "island", "swamp", "mountain", "forest"]
const COLORS := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G]


func build() -> CardData:
	return CardData.new("Phantasmal Terrain", "{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.static_ability(StaticAbility.new(
			_apply, "Enchanted land is the chosen basic land type.") \
			.changing_land_types()) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _name_the_type,
			"As this Aura enters, choose a basic land type.",
			_is_self)) \
		.oracle("Enchant land\nAs this Aura enters, choose a basic land type.\n"
			+ "Enchanted land is the chosen type.")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _choose(game: MtgGame, host: CardInstance) -> int:
	var counts := [0, 0, 0, 0, 0]
	for inst in game.all_battlefield():
		if inst == host or inst.controller_id != host.controller_id or not inst.is_land():
			continue
		for i in TYPES.size():
			if inst.has_subtype(TYPES[i]):
				counts[i] += 1
	var best := 0
	for i in TYPES.size():
		if counts[i] < counts[best]:
			best = i
	return best


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


## The arrival trigger, where the choice can be a real question: by now the
## Aura is attached, so the candidates can be judged against the host.
static func _name_the_type(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	source.memory["type"] = game.agents[pid].choose_option(game, pid,
		["Plains", "Island", "Swamp", "Mountain", "Forest"],
		"Choose a basic land type for %s" % source.data.card_name,
		_choose(game, host))
	game.recalculate()


static func _apply(game: MtgGame, source: CardInstance) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host == null or host.zone != Mtg.Zone.BATTLEFIELD:
		return
	# NOT cached: the arrival trigger has not asked yet, and writing the
	# hint here would answer the question before the player sees it.
	var index: int = int(source.memory.get("type", _choose(game, host)))
	host.become_basic_land_type(TYPES[index], COLORS[index])
