extends CardScript
## Psychic Allergy — {3}{U}{U} — Enchantment — (drk, rare)
## Oracle: As this enchantment enters, choose a color.
##         At the beginning of each opponent's upkeep, this enchantment
##         deals X damage to that player, where X is the number of nontoken
##         permanents of the chosen color they control.
##         At the beginning of your upkeep, destroy this enchantment unless
##         you sacrifice two Islands.
##
## Implementation: three clauses, two of them on the same event with
## opposite conditions — the enemy's upkeep burns them, yours charges rent.
## The colour is a real DecisionAgent choice (choose_color), hinted with
## the colour the opponent's board shows MOST of, and kept in the
## enchantment's card-local memory (Jihad's pattern).
##
## "Nontoken permanents of the chosen colour" counts LIVE colours and every
## permanent type, not just creatures — five Islands are five points if you
## called blue. Tokens are excluded exactly as printed.
##
## The rent wants TWO Islands, so one Island is no help at all: the
## enchantment dies with a single Island on the table.


const COLORS: Array[int] = [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G]


func build() -> CardData:
	return CardData.new("Psychic Allergy", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose,
			"As this enchantment enters, choose a color.",
			_is_self)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _burn,
			"At the beginning of each opponent's upkeep, this enchantment deals X damage to that player, where X is the number of nontoken permanents of the chosen color they control.",
			_enemy_upkeep)) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _pay_the_rent,
			"At the beginning of your upkeep, destroy this enchantment unless you sacrifice two Islands.",
			_own_upkeep)) \
		.oracle("As this enchantment enters, choose a color.\n"
			+ "At the beginning of each opponent's upkeep, this enchantment deals X damage "
			+ "to that player, where X is the number of nontoken permanents of the chosen "
			+ "color they control.\n"
			+ "At the beginning of your upkeep, destroy this enchantment unless you "
			+ "sacrifice two Islands.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := source.controller_id
	var enemy := game.opponent_of(pid)
	var hint: int = Mtg.ManaColor.U
	var best := -1
	for color in COLORS:
		var count := 0
		for inst in game.players[enemy].battlefield:
			if not inst.is_token and inst.has_color(color):
				count += 1
		if count > best:
			best = count
			hint = color
	source.memory["color"] = game.agents[pid].choose_color(
		game, pid, "Choose a color for Psychic Allergy", hint)


static func _own_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) == source.controller_id


static func _enemy_upkeep(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) != source.controller_id


static func _burn(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if not source.memory.has("color"):
		return   # the colour has not been chosen yet
	var victim := int(event.data["player"])
	var color := int(source.memory["color"])
	var count := 0
	for inst in game.players[victim].battlefield:
		if not inst.is_token and inst.has_color(color):
			count += 1
	game.deal_damage(source, TargetRef.player(victim), count)


static func _pay_the_rent(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var pid := int(event.data["player"])
	var islands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.has_subtype("island"):
			islands.append(inst)
	if islands.size() >= 2 and game.agents[pid].choose_yes_no(game, pid,
			"Sacrifice two Islands to keep %s?" % source.data.card_name, true):
		for _i in 2:
			var pick := game.agents[pid].choose_card(game, pid, islands,
				"Sacrifice an Island")
			if pick == null or not islands.has(pick):
				pick = islands[0]
			islands.erase(pick)
			game.sacrifice_permanent(pick)
		return
	game.destroy(source)
