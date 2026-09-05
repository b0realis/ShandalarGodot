extends CardScript
## Nameless Race — {3}{B} — Creature — */* — (drk, rare)
## Oracle: Trample
##         As this creature enters, pay any amount of life. The amount you
##         pay can't be more than the total number of white nontoken
##         permanents your opponents control plus the total number of white
##         cards in their graveyards.
##         Nameless Race's power and toughness are each equal to the life
##         paid as it entered.
##
## Implementation: an "as it enters" REPLACEMENT (CR 614.1c,
## CardData.as_it_enters) — a Race that settled its size a moment later
## would already have died as a 0/0 (CR 704.5f). The life paid is
## remembered in CardInstance.memory and published by a
## characteristic-defining static (CR 613 layer 7b).
##
## THE CAP is read live: every permanent an opponent controls that is white
## and not a token (CR 105 — colour is a characteristic, so a Dwarven Song
## repaint counts) plus every white card in an opponent's graveyard. CR
## 119.4 caps it again at the life its controller actually has: paying life
## you do not have is not a legal payment.
##
## THE HEURISTIC pays at most HALF its controller's life. A Race is a
## hate-card against white, and the printed ceiling is already the whole
## brake on it; spending past half your life for a body that a single
## Swords to Plowshares answers is not a price a player pays.
##
## mage-go deviates: it does not implement Nameless Race. Duel.hlp does not
## cover it — the shipped help file is the base game's pool, and The Dark
## arrived with the expansion.


func build() -> CardData:
	return CardData.new("Nameless Race", "{3}{B}", Mtg.CardType.CREATURE) \
		.pt(0, 0) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.as_it_enters(_pay) \
		.static_ability(StaticAbility.new(
			_apply,
			"Nameless Race's power and toughness are each equal to the life paid "
			+ "as it entered.").setting_base_pt()) \
		.oracle("Trample\nAs this creature enters, pay any amount of life. The "
			+ "amount you pay can't be more than the total number of white nontoken "
			+ "permanents your opponents control plus the total number of white cards "
			+ "in their graveyards.\nNameless Race's power and toughness are each "
			+ "equal to the life paid as it entered.")


## The printed ceiling: white nontoken permanents the opponents control,
## plus white cards in their graveyards.
static func white_ceiling(game: MtgGame, controller: int) -> int:
	var them := game.opponent_of(controller)
	var total := 0
	for inst in game.players[them].battlefield:
		if not inst.is_token and inst.has_color(Mtg.ManaColor.W):
			total += 1
	for inst in game.players[them].graveyard:
		if inst.data.color_mask() & Mtg.ManaColor.W:
			total += 1
	return total


static func _pay(game: MtgGame, inst: CardInstance, controller: int) -> void:
	# CR 119.4 — you may only pay life you have.
	var cap: int = mini(white_ceiling(game, controller),
		game.players[controller].life)
	if cap <= 0:
		inst.memory["paid"] = 0
		return
	var paid: int = game.agents[controller].choose_number(game, controller,
		0, cap, "Pay how much life to Nameless Race?",
		mini(cap, game.players[controller].life / 2))
	# SIZE FIRST, then the payment. adjust_life runs the state-based actions
	# and a Race still showing its printed 0/0 would be swept away by them
	# before it ever wore the body it just bought (CR 704.5f).
	inst.memory["paid"] = paid
	game.recalculate()
	if paid > 0:
		game.adjust_life(controller, -paid)


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	var n: int = maxi(0, int(source.memory.get("paid", 0)))
	source.cur_power = n
	source.cur_toughness = n
