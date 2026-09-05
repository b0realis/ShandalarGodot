extends CardScript
## Worms of the Earth — {2}{B}{B}{B} — Enchantment — (drk, rare)
## Oracle: Players can't play lands.
##         Lands can't enter the battlefield.
##         At the beginning of each upkeep, any player may sacrifice two
##         lands of their choice or have this enchantment deal 5 damage to
##         that player. If a player does either, destroy this enchantment.
##
## Implementation: TWO separate prohibitions, because the card prints two.
## - "Players can't play lands" is a play veto radiated to both players
##   (CardData.play_ban, the hook City in a Bottle introduced).
## - "Lands can't enter the battlefield" is an arrival ban radiated to both
##   players (CardData.enters_ban_rule, MtgGame.entry_refused). It is the
##   wider of the two and it is not implied by the first: a land PUT onto
##   the battlefield by an effect (Untamed Wilds) is not played, so only
##   this line stops it. A refused land stays in the zone it came from —
##   back into the library for a search, still in hand for a land drop,
##   which MtgGame.play_land reports as an ordinary refusal.
## The escape clause is an upkeep trigger that offers EACH player the
## way out, in APNAP order (CR 101.4: the active player first, then the
## other) as the trigger resolves — one DecisionAgent.choose_option per
## player (`WAYS`: "Sacrifice two lands." is on the list only for a player
## who has two, then "Take 5 damage.", then "Do nothing."). A player who
## sacrifices names the two lands themselves, one at a time
## (choose_card, `@SACRIFICE_X_BASICLAND`'s "Select %s to sacrifice."
## line). The Worms are destroyed ONCE however many players acted; a
## player asked after somebody already broke them is told so by the
## heuristic, which then does nothing. Manalink's continuation of the
## card (`../shandalar-src/src/cards/the_dark.c`, Tier 3 — the 1997 game
## never shipped it) put the same two answers to the active player
## alone; the printed "any player" is followed here.
##
## The heuristic: the controller keeps the Worms; the other player breaks
## them with two lands if they have them (the least valuable pair —
## untapped, aura-free basics first), takes the 5 if their life can stand
## it, and otherwise waits.


func build() -> CardData:
	return CardData.new("Worms of the Earth", "{2}{B}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.bans_playing(_is_a_land) \
		.bans_permanents_entering(_no_land_may_enter) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _offer_the_escape,
			"At the beginning of each upkeep, any player may sacrifice two lands or take 5 damage; either way, destroy this enchantment.")) \
		.oracle("Players can't play lands.\nLands can't enter the battlefield.\nAt the beginning of each upkeep, any player may sacrifice two lands of their choice or have this enchantment deal 5 damage to that player. If a player does either, destroy this enchantment.")


static func _is_a_land(_game: MtgGame, _pid: int, data: CardData) -> bool:
	return data.is_land()


## "Lands can't enter the battlefield" — every land, whoever owns it and
## however it was going to arrive. Reads the arriving object's LIVE type
## (CONTRIBUTING.md rule 5): a Living Lands animation does not stop a Forest
## being a land, and an animated Mishra's Factory that is bounced and
## replayed is still one.
static func _no_land_may_enter(_game: MtgGame, _source: CardInstance,
		entering: CardInstance, _controller: int) -> bool:
	return entering.is_land()


const SACRIFICE := "Sacrifice two lands."
const TAKE_5 := "Take 5 damage."
const NOTHING := "Do nothing."


static func _offer_the_escape(game: MtgGame, source: CardInstance,
		event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var active := int(event.data["player"])
	var broken := false
	for pid in [active, game.opponent_of(active)]:
		var lands := _lands_of(game, pid)
		var ways: Array[String] = []
		if lands.size() >= 2:
			ways.append(SACRIFICE)
		ways.append(TAKE_5)
		ways.append(NOTHING)
		var hint := ways.find(NOTHING)
		if pid != source.controller_id and not broken:
			if lands.size() >= 2:
				hint = ways.find(SACRIFICE)
			elif game.players[pid].life > 5:
				hint = ways.find(TAKE_5)
		var way: String = ways[game.agents[pid].choose_option(game, pid, ways,
			"Worms of the Earth: sacrifice two lands or take 5 damage?", hint)]
		if way == SACRIFICE:
			for _i in 2:
				lands = _lands_of(game, pid)
				if lands.is_empty():
					break
				var meal := game.agents[pid].choose_card(game, pid, lands,
					PlayerChoice.sacrifice_prompt("land"), false, false, true)
				if meal == null or not lands.has(meal):
					meal = lands[0]
				game.sacrifice_permanent(meal)
			broken = true
		elif way == TAKE_5:
			game.deal_damage(source, TargetRef.player(pid), 5)
			broken = true
	if broken:
		game.destroy(source)


## A player's lands, the ones they would miss least first: tapped or
## untapped basics without an aura before anything else, then by cost,
## then by id — the order their heuristic sacrifices in.
static func _lands_of(game: MtgGame, pid: int) -> Array[CardInstance]:
	var lands: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_land():
			lands.append(inst)
	lands.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var wa := _worth(game, a)
		var wb := _worth(game, b)
		if wa != wb:
			return wa < wb
		return a.id < b.id)
	return lands


static func _worth(game: MtgGame, land: CardInstance) -> int:
	var worth := 0
	if (land.data.supertypes & Mtg.Supertype.BASIC) == 0:
		worth += 10
	if land.is_creature():
		worth += 10
	for aura in game.all_battlefield():
		if aura.attached_to == land.id:
			worth += 5
	return worth
