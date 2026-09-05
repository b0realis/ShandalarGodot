extends CardScript
## Land Equilibrium — {2}{U}{U} — Enchantment — (leg, rare)
## Oracle: If an opponent who controls at least as many lands as you do
##         would put a land onto the battlefield, that player instead puts
##         that land onto the battlefield then sacrifices a land of their
##         choice.
##
## Implementation: the printed replacement and the implemented trigger are
## the same thing here, because the replacement's own text puts the land
## onto the battlefield first and only then takes one — so an
## ENTERS_BATTLEFIELD trigger on a land is observationally identical, and it
## fires for lands PUT onto the battlefield as well as lands played
## (Untamed Wilds, Sylvan Library's fetches), which is what the printed
## "would put" covers and a LAND_PLAYED trigger would not.
##
## The count is taken as the trigger RESOLVES, and "at least as many as you
## do" is checked then — the new land is already on the battlefield by that
## point, exactly as the printed order describes.
##
## Which land goes is the opponent's choice ("of their choice"), asked of
## THEIR agent and sorted from their point of view, so the heuristic gives
## up a tapped basic before an untapped dual.


func build() -> CardData:
	return CardData.new("Land Equilibrium", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _level,
			"If an opponent who controls at least as many lands as you do would put a land onto the battlefield, that player instead puts it onto the battlefield then sacrifices a land of their choice.",
			_an_opponents_land)) \
		.oracle("If an opponent who controls at least as many lands as you do would "
			+ "put a land onto the battlefield, that player instead puts that land "
			+ "onto the battlefield then sacrifices a land of their choice.")


static func _an_opponents_land(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	var inst: CardInstance = event.data["instance"]
	return inst.is_land() and int(event.data["controller"]) != source.controller_id


static func _level(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var them := int(event.data["controller"])
	var mine := _lands(game, source.controller_id).size()
	var theirs := _lands(game, them)
	# "If an opponent who controls AT LEAST AS MANY lands as you do WOULD
	# PUT a land onto the battlefield" — the applicability test of a
	# replacement effect, asked BEFORE the land is there (CR 614.1). The
	# printed ORDER is enter-then-sacrifice, which is why this is modelled
	# as an arrival trigger; the printed CONDITION still has to discount the
	# entrant, or the enchantment locks the opponent one land early and
	# holds them permanently below you instead of at parity.
	var entrant: CardInstance = event.data.get("instance")
	var before := theirs.size()
	if entrant != null and theirs.has(entrant):
		before -= 1
	if before < mine:
		return
	if theirs.is_empty():
		return
	theirs.sort_custom(_least_missed_first)
	var pick := game.agents[them].choose_card(game, them, theirs,
		"Sacrifice a land")
	if pick == null or not theirs.has(pick):
		pick = theirs[0]
	game.sacrifice_permanent(pick)


static func _lands(game: MtgGame, pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			out.append(inst)
	return out


## Tapped basics first: the land its controller misses least.
static func _least_missed_first(a: CardInstance, b: CardInstance) -> bool:
	var ab := (a.data.supertypes & Mtg.Supertype.BASIC) != 0
	var bb := (b.data.supertypes & Mtg.Supertype.BASIC) != 0
	if ab != bb:
		return ab
	if a.tapped != b.tapped:
		return a.tapped
	return a.id < b.id
