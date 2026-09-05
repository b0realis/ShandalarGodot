extends CardScript
## Wood Elemental — {3}{G} — Creature — Elemental — */* — (leg, rare)
## Oracle: As this creature enters, sacrifice any number of untapped Forests.
##         Wood Elemental's power and toughness are each equal to the number
##         of Forests sacrificed as it entered.
##
## Implementation: an "as it enters" REPLACEMENT (CR 614.1c,
## CardData.as_it_enters) — it has to be, because a Wood Elemental that
## settled its size a moment later would already have died as a 0/0 to the
## state-based actions (CR 704.5f). The count is remembered in
## CardInstance.memory and published by a characteristic-defining static
## (CR 613 layer 7b), so a Giant Growth still stacks on top of it.
##
## "Untapped Forests" reads the LIVE subtype, so a land turned into a
## Forest by Living Lands or Magical Hack feeds it, and a tapped one does
## not. The number is a real question (DecisionAgent.choose_number), and
## so is WHICH Forests go — one DecisionAgent.choose_card per Forest, with
## the original's line for the basic: `@SACRIFICE_X_BASICLAND`
## (Program/promptsX2.txt:117), "Select forest to sacrifice."
##
## THE HEURISTIC sacrifices EVERY untapped Forest. Keeping them makes a 0/0
## that dies before anything can look at it — the only Wood Elemental worth
## the four mana is the one that eats the whole forest — and the mana those
## lands would have made goes unspent this turn anyway, since the Elemental
## is a sorcery-speed play. The list it picks from comes least-missed
## first — Forests with nothing attached and no counters ahead of the
## rest (`edible_forests`) — so a Wild Growth survives where it can.
##
## mage-go deviates: it does not implement Wood Elemental at all (its
## Legends TODO lists it unimplemented). Duel.hlp does not cover it either
## — the shipped help file is the base game's, and Legends came with the
## expansion.


func build() -> CardData:
	return CardData.new("Wood Elemental", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_subtypes(["elemental"]) \
		.as_it_enters(_feed) \
		.static_ability(StaticAbility.new(
			_apply,
			"Wood Elemental's power and toughness are each equal to the number "
			+ "of Forests sacrificed as it entered.").setting_base_pt()) \
		.oracle("As this creature enters, sacrifice any number of untapped Forests.\n"
			+ "Wood Elemental's power and toughness are each equal to the number of "
			+ "Forests sacrificed as it entered.")


## The controller's untapped Forests, least missed first: anything with an
## Aura or a counter on it goes last. The order the picks are OFFERED in —
## the heuristic takes the first.
static func edible_forests(game: MtgGame, controller: int) -> Array[CardInstance]:
	var loose: Array[CardInstance] = []
	var loved: Array[CardInstance] = []
	for inst in game.players[controller].battlefield:
		if inst.tapped or not inst.has_subtype("forest"):
			continue
		if inst.counters.is_empty() and _nothing_attached(game, inst):
			loose.append(inst)
		else:
			loved.append(inst)
	loose.append_array(loved)
	return loose


static func _nothing_attached(game: MtgGame, land: CardInstance) -> bool:
	for inst in game.all_battlefield():
		if inst.attached_to == land.id:
			return false
	return true


static func _feed(game: MtgGame, inst: CardInstance, controller: int) -> void:
	var forests := edible_forests(game, controller)
	if forests.is_empty():
		inst.memory["forests"] = 0
		return
	var count: int = game.agents[controller].choose_number(game, controller,
		0, forests.size(),
		"Sacrifice how many untapped Forests to Wood Elemental?",
		forests.size())
	var meal: Array[CardInstance] = []
	for i in count:
		if forests.is_empty():
			break
		var pick := game.agents[controller].choose_card(game, controller,
			forests, PlayerChoice.sacrifice_prompt("Forest"), false, false, true)
		if pick == null or not forests.has(pick):
			pick = forests[0]
		forests.erase(pick)
		meal.append(pick)
	# SIZE FIRST, then the meal: sacrificing runs the state-based actions,
	# and an Elemental still showing its printed 0/0 would be swept away by
	# them before it ever wore the body it just paid for (CR 704.5f).
	inst.memory["forests"] = meal.size()
	game.recalculate()
	for forest in meal:
		game.sacrifice_permanent(forest)


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	var n: int = maxi(0, int(source.memory.get("forests", 0)))
	source.cur_power = n
	source.cur_toughness = n
