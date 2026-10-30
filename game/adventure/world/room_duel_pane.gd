class_name RoomDuelPane
extends StagePane
## BEFORE A ROOM'S DUEL INSIDE A CASTLE OR A DUNGEON (part C, stage C2) —
## the owner's ruling c2-15 of 2026-10-27, "Show what's at stake" [ours]:
## 1997 met a room's creature with a text box over the board and nothing
## else (`RunDungeonMonsterDuel`, dungeonEncounter.c 809–825: "Exploring the
## Castle... / you encounter a Greater Lich!", `Dngnduel.wav`) — no face,
## no stake shown before the duel. Here, over the board (the board's pane
## waits under it, [DungeonPane]), one of the world's rounded panes
## ([StagePane]) shows, on the meeting's ground of the place's colour
## (`preduel_<colour>`, as a creature met on the world):
##  - THE CREATURE'S FACE in its frame, its name on the banner
##    ([method EncounterStage.creature_face]) — the pane's header says only
##    what it is, "Creature" or "Wizard" ([method CreatureBook.kind_word]);
##  - "Your Ante" over THE HERO'S STAKE ([method DungeonDuels.draw_stake]),
##    or "No stake" — the dungeon's rules allowing none of the cards that
##    could be staked (the owner's f2, [DungeonDuels]): the note says so;
##  - under it, small, the hero's own cards that start in play — the
##    world's next-duel card and the dice's ([method hero_in_play]);
##  - "In Play" over what the creature starts with: a castle's MINION
##    ("Greater Lich has the spell Hypnotic Specter!") and THE CARD IN
##    EFFECT, in the board's green marble frame (`Dungbutt.spr` frame 0,
##    `dungeon_plaques`) — "(Gloom starts in play!)";
##  - the purse (gold, food, the deck, the LIFE THE HERO STARTS THIS DUEL
##    WITH: the links, the lives carried, the world's gift and the run's
##    pool — [method DungeonDuels.hero_life]; the meeting's purse shows the
##    links alone);
##  - under the page, 1997's own words ([method DungeonDuels.words]) and
##    ONE CHOICE, "Duel".
## Every card on it is read full screen with a right click.
##
## THE WAY ON IS THE DUEL: there is no flight, as part B's meetings —
## Escape does nothing (1997 took any key as "go on"); D lights "Duel",
## Enter or Space takes it. [signal chosen] with [constant DUEL], once; the
## pane then takes itself away and the caller holds the duel
## ([method WorldDuels.host] with [method DungeonDuels.duel_config]).
## `sfx_dungeon_duel` (`Dngnduel.wav`, 1997's box's sound) is the board's,
## played as it opens this pane ([DungeonPane]'s sounds, [DungeonSound]):
## the pane plays none of its own, so it is heard once.
##
## THE STAKE IS DRAWN BEFORE, BY THE CALLER: [member duel] is [method
## DungeonDuels.setup_room]'s set-up after [method DungeonDuels.draw_stake]
## answered true (false is the game over: no pane, the end screen). The
## pane draws nothing — no dice — so the card shown is the card at stake;
## an empty stake is "No stake". Given a set-up whose draw found nothing to
## stake at all (`no_ante`), it says 1997's "You have no power for even an
## Ante!" and its one choice still answers [constant DUEL]: the caller
## reads `no_ante` and takes the game's end ([constant
## DungeonDuels.GAME_OVER]).

## The hero goes on: "duel" (the only answer).
signal chosen(what: String)

const DUEL := "duel"
const DUEL_WORDS := "Duel"
## [Ours] The right plaque's word, and the captions.
const IN_PLAY := "In Play"
const NO_STAKE := "No stake"
const NO_STAKE_NOTE := "The rules here allow none of the cards you could stake: you stake nothing."
const ITS_SPELL := "Its spell"
const IN_EFFECT := "In effect"
const YOURS_IN_PLAY := "Yours in play"
## `Dungbutt.spr` frame 0 (`dungeon_plaques`): the green marble frame the
## board shows the card in effect in, and the card's place inside it.
const EFFECT_FRAME := Rect2(0, 0, 201, 281)
const CARD_IN_FRAME := Rect2(29, 48, 143, 204)
## The frame on the page: its scale, and where it stands — under the
## minion, or at the top of the column when there is none.
const EFFECT_SCALE := 0.72
const EFFECT_LOW := Vector2(470, 248)
const EFFECT_HIGH := Vector2(470, 44)
## The minion under "In Play" (the meeting's opponent's stake place).
const MINION_AT := EncounterStage.CREATURE_CARD_AT
## The hero's cards in play under the stake: small, a step apart.
const YOURS_AT := Vector2(36, 236)
const YOURS_WIDTH := 64.0
const YOURS_STEP := 70.0

## The board's run record ([member DungeonBoard.run]).
var run := {}
## The duel about to be fought ([method DungeonDuels.setup_room], its stake
## drawn by [method DungeonDuels.draw_stake]).
var duel := {}
var _chosen := false


## THE PANE for [param player] before the duel [param duel] of the run
## [param run]: not yet in the tree (the caller adds it, centres it —
## [method PaneStyle.centre] — and sets [member k]).
static func make(player: AdventurePlayer, run: Dictionary, duel: Dictionary) -> RoomDuelPane:
	var pane := RoomDuelPane.new()
	pane.player = player
	pane.run = run
	pane.duel = duel
	return pane


func _ready() -> void:
	super._ready()
	name = "RoomDuelPane"
	var row := int(duel.get("row", 0))
	# What it is, alone: its face's banner names it (the owner, 2026-10-30:
	# "Yes, header = kind").
	set_title(CreatureBook.kind_word(row) if row > 0 else "")
	draw_page()
	var lines: Array[String] = DungeonDuels.words(duel) if row > 0 else [] as Array[String]
	if bool(duel.get("no_ante", false)):
		lines = [CreatureMeeting.NO_ANTE[0]] as Array[String]
	say(lines)
	offer([[DUEL, DUEL_WORDS, true]], NO_STAKE_NOTE if stakes_nothing() else "")


## THE PAGE (the class doc): the ground, the face, the stake, what starts
## in play on either side, the purse.
func draw_page() -> void:
	stage.clear()
	var row := int(duel.get("row", 0))
	var color := clampi(int(duel.get("color", DungeonDuels.color_of(player, run))), 1, 5)
	stage.hue = color
	stage.ground("preduel_" + AdventurePlayer.COLORS[color - 1])
	if row > 0:
		stage.creature_face(row)
	# The hero's side: the stake under "Your Ante", or "No stake".
	stage.piece("preduel_frame", EncounterStage.HERO_PLAQUE, EncounterStage.HERO_PLAQUE_AT, "HeroPlaque")
	stage.words(CreatureMeeting.ANTE_WORDS[1], EncounterStage.HERO_PLAQUE_AT, 15, PaneStyle.GOLD,
		"HeroPlaqueWords")
	var staked := stake()
	if staked != "":
		stage.card(staked, EncounterStage.HERO_CARD_AT, EncounterStage.CARD_WIDTH, "Stake")
	else:
		var box := Rect2(EncounterStage.HERO_CARD_AT, Vector2(EncounterStage.CARD_WIDTH,
			EncounterStage.CARD_WIDTH * CardPreview.SIZE.y / CardPreview.SIZE.x))
		stage.piece("", Rect2(), box, "NoStakeBox")
		stage.words(NO_STAKE, box.grow(-8), 16, PaneStyle.DIM, "NoStake", true)
	var yours := hero_in_play()
	for i in yours.size():
		stage.card(yours[i], YOURS_AT + Vector2(YOURS_STEP * i, 0), YOURS_WIDTH, "Yours%d" % i)
	if not yours.is_empty():
		var high := YOURS_WIDTH * CardPreview.SIZE.y / CardPreview.SIZE.x
		stage.words(YOURS_IN_PLAY, Rect2(YOURS_AT + Vector2(-8, high + 2),
			Vector2(YOURS_STEP * (yours.size() - 1) + YOURS_WIDTH + 16, 18)), 13, PaneStyle.GOLD, "YoursCaption")
	# The creature's side: what it starts with in play.
	var minion := String(duel.get("minion", ""))
	var effect := String(duel.get("effect", ""))
	if minion != "" or effect != "":
		stage.piece("preduel_frame", EncounterStage.CREATURE_PLAQUE, EncounterStage.CREATURE_PLAQUE_AT,
			"InPlayPlaque")
		stage.words(IN_PLAY, EncounterStage.CREATURE_PLAQUE_AT, 15, PaneStyle.GOLD, "InPlayWords")
	if minion != "":
		stage.card(minion, MINION_AT, EncounterStage.CARD_WIDTH, "Minion", ITS_SPELL)
	if effect != "":
		var at := Rect2(EFFECT_LOW if minion != "" else EFFECT_HIGH, EFFECT_FRAME.size * EFFECT_SCALE)
		stage.piece("dungeon_plaques", EFFECT_FRAME, at, "EffectFrame")
		stage.card(effect, at.position + CARD_IN_FRAME.position * EFFECT_SCALE,
			CARD_IN_FRAME.size.x * EFFECT_SCALE, "Effect")
		stage.words(IN_EFFECT, Rect2(at.position.x, at.end.y + 1, at.size.x, 18), 13, PaneStyle.GOLD,
			"EffectCaption")
	if player != null:
		stage.purse(player)
		_life_in_purse(DungeonDuels.hero_life(player, run))


## The purse's life: the life this duel starts with (the class doc).
func _life_in_purse(life: int) -> void:
	var line := stage.part("Life") as Label
	if line == null:
		return
	line.text = str(life) if GameSkin.texture("preduel_panels") != null else "Life %d" % life


## The card at stake, "" for none.
func stake() -> String:
	var staked: Array = duel.get("hero_ante", [])
	return String(staked[0]) if not staked.is_empty() else ""


## Whether the hero stakes nothing though there were cards to stake (the
## rules allow none — the owner's f2).
func stakes_nothing() -> bool:
	return stake() == "" and not bool(duel.get("no_ante", false))


## THE HERO'S CARDS THAT START IN PLAY, as [method DungeonDuels.duel_config]
## puts them: the world's next-duel card, then the dice's unless the rules
## bar it.
func hero_in_play() -> Array[String]:
	var out: Array[String] = []
	if player == null:
		return out
	if player.next_duel_card != "" and CardRegistry.has_card(player.next_duel_card):
		out.append(player.next_duel_card)
	var dice_card := String(DungeonDuels.read(run, "dice_card", ""))
	if dice_card != "" and CardRegistry.has_card(dice_card) \
			and not DungeonDuels.bars(dice_card, int(duel.get("rules", 0)), int(duel.get("color", 0))):
		out.append(dice_card)
	return out


## "Duel": [signal chosen], once; the pane taken away after.
func choose(action: String) -> void:
	if action != DUEL or _chosen:
		return
	_chosen = true
	chosen.emit(DUEL)
	PaneStyle.drop(self)


## Whether "Duel" was taken.
func was_chosen() -> bool:
	return _chosen


## Escape: nothing — there is no flight (the class doc).
func escape() -> void:
	pass
