class_name DungeonBoard
extends RefCounted
## THE BOARD OF A CASTLE OR A DUNGEON (part C, 2026-10-27) — 1.3's
## `RunCastleDungeonBoard` (dungeonEncounter.c 187–741, with
## `PopulateDungeonCellEvents` 1643–1783, `MarkDungeonDistanceFromCell`
## 1609, `RevealDungeonCellAndNeighbors` 1420–1460; retail Palette.c
## 6380–6760 and 6880–6940 run the same rules with the same constants)
## between the two doors of [DungeonDoors]: what happens INSIDE, headless
## — the maze, its rooms, the moves, the events and what each gives — so the
## board's pane (part C's second stage) only draws it and asks the player.
## The doors stay [DungeonDoors]' (the journal, the attempt counted, roaming
## slots 0–4 emptied going in; the gifts kept, a dungeon moved, a castle's
## retaliation coming out); a room's duel is [DungeonDuels]'.
##
## THE GRID. 15 × 13 cells, x 0–14 across, y 0–12 down ([member cells],
## `x · 13 + y`), each 1997's own int: 0 solid (wall, pillar, border, a
## closed passage); [constant OPEN] 0x001; the event in bits 0x0F0 — 1 dice,
## 2 a scroll, 3–6 a room of creature slot 0–3, 7 a treasure, 15 the castle
## wizard —; [constant SEEN] 0x100. A cell done is [constant PASSED] 0x101; a
## scroll answered wrong [constant SUMMONED] 0x61 (a slot-3 room, not yet
## seen). THE LATTICE (dE:345–382): every cell open but the border (x 0, y
## 0, x ≥ 14, y ≥ 12), the pillars (x and y both even) and the four cut
## corners (3 × 3 at each end of the diamond), then the entrance (7, 12)
## opened — 38 rooms (odd x and y), 63 passages (one coordinate odd), 102
## open cells. The hero starts at (7, 11). Every cell is a step: the hero
## stands in passages as in rooms.
##
## THE MAZE IS MADE BY CLOSING PASSAGES (dE:383–405), from the open
## lattice, with the hero standing on the entrance: a cell `gx = rand(7)·2`,
## `gy = rand(6)·2`, then `rand(2)` — not 0 → gx + 1, else gy + 1 (a
## passage, or a border cell already solid) — is closed, and the maze judged
## ([method _judge], 1997's first pass): every open cell reachable from the
## entrance; every DEAD END (a cell with one open neighbour — only rooms can
## be) at DEPTH ≥ 16 and no two on one row (the scan's rows, y outer, x
## inner, entrance skipped). Broken: the closure is undone. Fine with fewer
## than three dead ends: kept, and on. Fine with three or more: kept, the
## rooms' events placed, done. DEPTH ([member depth], `MarkDungeonDistance-
## FromCell`) is the shortest path from the entrance + 1 (the entrance 1, 0
## where nothing reaches); it is the generation's, never measured again.
## THE GUARD [ours: 1997 slip N1 — the loop had no way out: closures can
## leave a maze no further closure mends (every open passage a bridge, or
## every other closure a dead end too shallow or on a taken row), and 1997
## drew forever, about one entry in 2,500 (the research's 12,400 simulated
## entries; the owner's ruling D8, as the world generator's own GUARD)]:
## the candidate cells whose closure was undone since the grid last changed
## are kept; when every open candidate is among them, the maze can never
## finish, and it starts again from the fresh lattice, the dice going on.
## Exact: every maze 1997 finishes comes out the same (pinned by the tests
## against an unguarded run).
##
## THE ROOMS' EVENTS (dE:1721–1783, 1997's second pass, the same scan):
## every dead end a TREASURE — but a castle's first in scan order (the
## lowest row, the board's far side), which is THE WIZARD's room; any other
## open cell whose depth d has `(min − d + 1) % m == 0`, `d < max` and `d ≥
## 8` (min and max the dead ends' depths, `m = 5 − min(tries + difficulty,
## 3)`: every 5th layer of depth on the first entry on Apprentice, every 2nd
## from tries + difficulty 3 — re-entering makes the rooms denser) gets the
## event `clamp((d − min) / 4 − 2 + rand(6) + ways + corners, 0, 6)` (the
## division toward zero, as C's; `ways` its open neighbours, `corners` its
## open diagonal ones — 0 for a room, 0–4 for a passage), then the dice
## instead one time in `difficulty + 3` (`rand(difficulty + 3) == 0`). 0
## leaves it empty. So the deeper, the more connected and the more corridor,
## the stronger the room.
##
## THE FIVE CREATURES (dE:275–344): slot s's tier, a dungeon `[4, 6, 8, 12,
## 16, 18, 18][s + 2 if large]` (`monster_flags & 0x80`), so a dungeon's
## creatures are fixed by its colour and size — the clue "small black
## creatures" names them; a castle `[10, 11, 12, 13, 14, 16][rand(6)]`
## drawn again with every retry, its slot 4 at 18; [method
## CreatureBook.pick] of the slot's colour, again until a creature (a white
## castle's tier 13 has none). A castle's slot 4 is then picked again at
## tier 20: its wizard ([method CreatureBook.castle_row]). Rooms 3–6 hold
## slots 0–3, the wizard's room slot 4. DESIGNED, NEVER USED (N8): a
## dungeon's fifth creature (tier 16, or 18 when large) is picked and its
## figure loaded, and no event ever leads to it — kept so here.
##
## GOING IN ([method enter], after [method DungeonDoors.enter], in 1997's
## order): the pool at 0; 195 draws `rand() & 3`, the floors' looks
## ([method look]; written row by row and read column by column, as 1997
## did, so cells x = 13 from y = 2 and all of x = 14 read look 0); a
## dungeon's tile sheet (`rand(3)`: `dungeon_tiles_1|2|3`; a castle wears its
## colour's, `dungeon_tiles_<colour>`); the five creatures; the maze; the
## hero on the start, facing 4, and the first look round ([method reveal]).
## THE DICE [ours, the lead's D3]: 1997 reseeded `rand()` from the clock as
## the board began (`SeedRandomFromTickCount`, dE:245), so every entry was a
## new maze; ours does the same on a dice of the board's own ([member
## dice]: a clock seed, or one a test injects) — the maze, the creatures and
## every event's draws in 1997's order on it, and the adventure's dice
## ([member AdventurePlayer.dice]) untouched. With the owner's D2 (an
## autosave at the door, nothing saved inside) a quit inside puts the hero
## back at the door, and the next entry draws a new maze. The ambient
## sounds' timer (1997's `rand(90)` after the maze) is the view's, on its
## own dice.
##
## MOVING ([method step], dE:449–696): 1 −y (Home, up-left on the screen), 3
## +x (PgUp, up-right), 5 +y (PgDn, down-right), 7 −x (End, down-left); the
## hero turns to `(direction + 1) % 8 + 1` whatever comes; a wall does
## nothing; an event cell is entered as an EVENT, the hero standing before
## it ([member pending]) until its page resolves it — passed (the hero
## moves in) or pushed back; the entrance asks to leave [ours, the owner's
## board extras: "Leave?" — 1997 left on the step]. The pane's keys [ours,
## the owner's P4 "Modern": [method direction_of_key] — 1997's four, the
## keypad 7/9/3/1 whatever NumLock says, the arrows and W A S D turned to the
## diagonals], the mouse's quadrants round the hero ([method
## direction_toward], dE:1552–1606), a click along a seen straight corridor
## ([method walk_toward], stopping at the first event) [QoL]. SEEING
## ([method reveal]): the hero's cell, and down each of the four ways every
## open cell to the first wall — so an event, and which creature waits in a
## room, shows wherever it lies in a straight open line from the hero.
##
## THE EVENTS (dE:493–669), each resolved by its own call:
##  - THE DICE ([method roll_dice], dE:506–537): a coin `rand() & 1`; odd,
##    1–3 lives (`rand(3) + 1`) into the pool; even, a card of the deck in
##    use put in play in the next room duel ([member dice_card]): `rand(500)`
##    over the bag again until a creature or an artifact of the deck in use
##    — every copy alike. "You get +2 (14) Lives\nin the next duel!" — the
##    life the next duel will start with ([method next_duel_life]) — or the
##    card's name. [ours: 1997 slip k — and never a card the dungeon's rules
##    bar ([method bars]; the owner's ruling k2).] [ours: 1997 slip N2 — a
##    deck in use with no creature and no artifact (none allowed) drew
##    forever: the dice gives the lives then (the owner's D9).] One slot, as
##    1997's: a later dice replaces the dice's waiting card, lives already
##    won stay in the pool.
##  - THE SCROLL ([method riddle], [method riddle_answered], dE:538–553):
##    the lairs' riddle ([CardRiddle], on the board's dice). Right: passed.
##    Wrong: the cell becomes a room of slot 3 — the strongest creature —
##    the hero stays and sees it at once. Nothing is staked. (1997 took
##    Escape as a wrong answer; the pane waits for one, as a meeting's
##    riddle does.)
##  - A ROOM (events 3–6) and THE WIZARD'S ROOM (15): the duel is
##    [DungeonDuels]'; the board takes its outcome ([method room_done]):
##    cleared (passed), again (the owner's g3 — a draw is no result: pushed
##    back, the creature stays), thrown out (a room lost: every castle and
##    dungeon carries rule 0x01, so the visit ends — booted from a castle;
##    the cell turns solid as 1997's did, unseen), left (the wizard's duel
##    lost: out, no booted words), beaten (the wizard: out, the castle won —
##    [CastleWin]), game over (no card to stake).
##  - A TREASURE ([method open_treasure], dE:580–633): while the dungeon
##    holds a card, one of them at random (1997's `rand(3)` over its three
##    places, here `rand(left)` over the list — the same odds) joins the bag
##    in no deck, "Found This Card", and leaves the dungeon's list (the
##    journal "treasure"; "Acquired spell" for a rare card — with the 1997
##    program's card table every dungeon card is special).
##    [ours: 1997 slip N5 — a full bag (500) wrote past the bag and the card
##    was lost to the game for good, one of the 28 unique treasures: the
##    owner's D12 — the find says `bag_full`, and the pane offers to leave
##    one of the hero's cards behind for it ([method treasure_swap]);
##    declined ([method treasure_declined]), the card stays in the
##    dungeon.] [ours, the owner's ruling of 2026-10-27: "the card the hero
##    puts back STAYS AS TREASURE in that dungeon, to be found again on a
##    later visit" — kept in the slot's [constant WorldClues.LEFT_CARDS],
##    drawn by a later visit's dead ends among the dungeon's own cards
##    (never again on the visit it was left on), and counted as the
##    dungeon's while it waits: the dungeon lasts, its clue lists it
##    ([method WorldClues.holds_cards]).] Otherwise gold, `rand(100) · (difficulty + 2) + 100` down to
##    a multiple of 10 (Apprentice 100–290 … Wizard 100–590), and for each
##    colour black … white `rand(2)` amulets: "Found %d Gold" — "and a bag
##    with Jewels:" and a line a colour. Every castle treasure is gold:
##    castles hold no cards.
##  [ours: 1997 slip (c), the owner's ruling — a dungeon lasts while any of
##  its cards remains: its `cards` is a list, any card left — a card the
##  hero left behind in it too — keeps it on the world ([method
##  WorldClues.known]), where 1997 hid it with its first place emptied.]
##
## THE LIFE POOL AND THE NEXT DUEL (dE:249, 513, 896–906; the owner's (a)
## and d2): [member life_pool] is 0 on entry and on leaving; the dice add to
## it; after each room's duel [DungeonDuels] writes it in the run record
## (`settle`): rule 0x01 adds the duel's net change (a dungeon carries its
## losses room to room) and rule 0x02 zeroes it (a castle's duels each
## start fresh: links and the dice since the last duel — a1, as played); a
## draw touches nothing (g3b). The board keeps it between rooms. The
## next room duel's life ([method next_duel_life]) is the mana links + the
## lives carried + the world's lives gift (spent by the duel that uses it,
## d2 [ours: 1997 slip d — 1997 wiped a world lives gift unapplied]) + the
## pool. The line under the title ([method next_duel_line], 1997's
## `AppendDungeonRewardDescription`) says what waits.
##
## LEAVING ([method close]; Escape, the exit clicked or walked onto, a room
## lost, the wizard's room ended, a game over): a castle left after a lost
## room says "You are unceremoniously booted from\nthe stronghold of the
## Mighty %s!" (`@DUNGEON` 11/12, the same words for both); the pool and the
## dice's card are spent; the world's next-duel gifts are KEPT (the owner's
## D-4, [DungeonDoors]). What it returns — `{index, beaten, booted,
## game_over, words}` — is what [method DungeonDoors.leave] and the world
## screen's seam ([method WorldScreen._board_done]) read; the dungeon's move
## is [DungeonDoors]'.
##
## THE RUN RECORD ([member run]) — THE CONTRACT WITH [DungeonDuels] (c2
## §12.5): one Dictionary, handed out BY REFERENCE, so what the duels write
## the board reads; the board's own fields of the same names are views of
## it. A hand-made record of these keys stands in for a board:
##  - `index` int — the world's slot, 0–4 a castle (black … white), 5–14 a
##    dungeon ([member ShandalarWorld.encounters]);
##  - `castle` bool — a wizard's castle;
##  - `color` int — the slot's colour, 1 black … 5 white;
##  - `rules` int — the slot's rules word: 0x01 losses carried (every
##    castle and dungeon), 0x02 a castle's fresh duels, 0x10 no cards of
##    its colour, 0x20 one deck for all duels (no reader), 0x40 no
##    artifacts, 0x80 no instants or interrupts, 0x200 the clue mark
##    ([constant WorldClues.CARDS_TAKEN], no effect);
##  - `monsters` Array[int] — five [CreatureBook] rows: slots 0–3 the rooms
##    (events 3–6), slot 4 a castle's wizard (event 15) or a dungeon's
##    unmet fifth;
##  - `life_pool` int — the pool above, read and written by the duels;
##  - `dice_card` String — the card the dice put in play for the next room
##    duel, "" for none; the duel reads it and clears it;
##  - `code` int — the event of the room the hero is stepping into: 3–6 a
##    room of creature slot `code − 3`, 15 the castle wizard (slot 4); 0
##    between rooms ([method monster_slot]);
##  - and, beside the contract, `card_in_effect` int — the slot's card in
##    effect, its 1.3 id ([constant WorldClues.EFFECT_CARDS]), −1 for none.
##
## DESIGNED, NEVER USED (kept dead): the dungeon's fifth creature (N8,
## above); `g_dungeon_force_final_encounter` (dE:244, 500: every event cell
## the castle wizard's room; only ever set to 0); the dice's "id 5 → none"
## and "none → draw again" (dE:532, 1532: unreachable); "First Move" from
## the dice (the dice writes lives or a card, never 0) — the line shows it
## only for the world's gift.

# ----------------------------------------------------------------- the grid --

const WIDTH := 15
const HEIGHT := 13
const CELLS := WIDTH * HEIGHT
## Where the hero comes in and goes out, and where the hero starts.
const ENTRANCE := Vector2i(7, 12)
const START := Vector2i(7, 11)
## No cell (no event pending).
const NOWHERE := Vector2i(-1, -1)
## 1997's cell bits (dE:535, 543).
const OPEN := 0x001
const EVENT_SHIFT := 4
const EVENT_MASK := 0x0F0
const SEEN := 0x100
const PASSED := 0x101
const SUMMONED := 0x61
## The events.
const DICE := 1
const SCROLL := 2
const ROOM_FIRST := 3
const ROOM_LAST := 6
const TREASURE := 7
const WIZARD := 15
## A dead end's least depth, and an event's.
const DEAD_END_DEPTH := 16
const EVENT_DEPTH := 8
## The least dead ends a finished maze has.
const DEAD_ENDS := 3

# ------------------------------------------------------------ the creatures --

const MONSTERS := 5
const WIZARD_SLOT := 4
const DUNGEON_TIERS: Array[int] = [4, 6, 8, 12, 16, 18, 18]
const CASTLE_TIERS: Array[int] = [10, 11, 12, 13, 14, 16]
const CASTLE_FIFTH_TIER := 18
const WIZARD_TIER := 20
## `monster_flags` 0x80: a large dungeon (every castle carries it too).
const LARGE := 0x80
## How many times a slot's pick is drawn again before the GUARD takes the
## colour's first creature of a tier — never reached with 1997's table
## (every colour has a creature at every dungeon tier, a castle redraws its
## tier each time).
const PICK_ROUNDS := 100

# ----------------------------------------------------------------- the rules --

## Life losses carried over (every castle and dungeon).
const CARRIES := 0x01
## Remaining life added to the next duel — in 1997's code the pool zeroed:
## a castle's duels each start fresh (the owner's a1).
const FRESH := 0x02
## No cards of the slot's colour; no artifacts; no instants or interrupts.
const NO_COLOR := 0x10
const NO_ARTIFACTS := 0x40
const NO_INSTANTS := 0x80

# ------------------------------------------------------------------ moving --

## The four ways (1997's `g_neighbor_dx/dy`, the odd ones): 1 −y, 3 +x, 5
## +y, 7 −x.
const UP_LEFT := 1
const UP_RIGHT := 3
const DOWN_RIGHT := 5
const DOWN_LEFT := 7
const STEPS := {1: Vector2i(0, -1), 3: Vector2i(1, 0), 5: Vector2i(0, 1), 7: Vector2i(-1, 0)}
## The hero's facing as a board begins (the program-wide start, dE:135).
const START_FACING := 4

# ------------------------------------------------- the duels' outcomes --

## What [DungeonDuels] says of a room's duel ([method room_done]).
const CLEARED := "cleared"
const AGAIN := "again"
const THROWN_OUT := "thrown_out"
const LOST := "lost"
const LEFT := "left"
const BEATEN := "beaten"
const GAME_OVER := "game_over"

# --------------------------------------------------------------- the words --

## `@DUNGEON` 0–14, word for word (1997's last "\n" left off, as
## [constant LairDuels.STARTS_IN_PLAY]).
const YOU_GET := "You get %s\nin the next duel!"
const LIVES := "+%d (%d) Lives"
const FIRST_MOVE := "First Move"
const FOUND_CARD := "Found This Card"
const FOUND_GOLD := "Found %d Gold"
const FOUND_JEWELS := "Found %d Gold\nand a bag with Jewels:\n%s"
const JEWELS: Array[String] = ["%d black", "%d blue", "%d green", "%d red", "%d white"]
const BOOTED := "You are unceremoniously booted from\nthe stronghold of the Mighty %s!"
const EXIT := "Exit"
const IN_EFFECT := "%s in effect."
## A maze's attempts at most when [method generate] runs unguarded — a
## test's comparison with 1997's own endless loop, never the game's (a
## maze 1997 finishes takes about 38 closures, the most seen 307).
const UNGUARDED_MOST := 5000


## THE RUN RECORD — the contract with [DungeonDuels] (the class's notes).
var run := {"index": -1, "castle": false, "color": 0, "rules": 0, "monsters": [] as Array[int],
	"life_pool": 0, "dice_card": "", "code": 0, "card_in_effect": -1}

## The world's slot, 0–4 a castle, 5–14 a dungeon ([member run]).
var index: int:
	get:
		return int(run["index"])
	set(value):
		run["index"] = value
## A wizard's castle.
var castle: bool:
	get:
		return bool(run["castle"])
	set(value):
		run["castle"] = value
## The slot's colour, 1 black … 5 white.
var color: int:
	get:
		return int(run["color"])
	set(value):
		run["color"] = value
## The slot's rules word.
var rules: int:
	get:
		return int(run["rules"])
	set(value):
		run["rules"] = value
## The five creatures' rows.
var monsters: Array[int]:
	get:
		return run["monsters"]
	set(value):
		run["monsters"] = value
## The dungeon's life pool.
var life_pool: int:
	get:
		return int(run["life_pool"])
	set(value):
		run["life_pool"] = value
## The dice's card in play for the next room duel, "" for none.
var dice_card: String:
	get:
		return String(run["dice_card"])
	set(value):
		run["dice_card"] = value
## The event of the room being stepped into, 0 for none.
var code: int:
	get:
		return int(run["code"])
	set(value):
		run["code"] = value

## The cells, `x · 13 + y`, 1997's bits.
var cells := PackedInt32Array()
## The generation's depths from the entrance (1 the entrance, 0 unreached).
var depth := PackedByteArray()
## The floors' looks, 0–3, as 1997 stored them ([method look]).
var looks := PackedByteArray()
## The board's dice (the class's notes).
var dice: MsvcRandom
## 1997's `times_entered` as the rooms read it ([method DungeonDoors.enter]'s
## `tries`: 0 the first time) and the difficulty, 0 Apprentice … 3 Wizard.
var tries := 0
var difficulty := 0
## A dungeon's tile sheet 1–3 (0 for a castle) and the sheet's skin key.
var tiles := 0
var sheet := ""
## Where the hero stands, and which way the figure looks (1, 3, 5, 7; 4 at
## the start).
var hero := START
var facing := START_FACING
## The event cell the hero stands before, its page open ([constant NOWHERE]
## for none).
var pending := NOWHERE
## The dice's lives waiting for the next room duel (the gift line's "+n";
## they are in the pool already), 0 for none.
var dice_lives := 0
## Thrown out after a lost room, the castle's wizard beaten, the board
## ended (no more steps), the game over.
var booted := false
var beaten := false
var over := false
var game_over := false
## The riddle asked at a scroll, `{}` for none ([CardRiddle]).
var asked := {}
## A card found with a full bag, waiting for the swap ([method
## _treasure_pool]'s entry): `{card, treasure}` — its name and its
## [constant ShandalarWorld.DUNGEON_CARDS] index — or `{card, left: true}`,
## a card the hero left behind on an earlier visit.
var found := {}
## The cards the hero left behind on this visit ([method treasure_swap]):
## they wait in the dungeon for a later one.
var left_here: Array[String] = []
## The closures tried in all (every restart's too) and the GUARD's
## restarts; the dice's state as the last closure was judged, before the
## rooms' events were drawn (the tests' golden vectors).
var attempts := 0
var restarts := 0
var maze_dice := 0


# ------------------------------------------------------------- going in --

## THE BOARD OF [param setup] ([method DungeonDoors.enter]'s `{index,
## castle, color, tries}`) for [param player], in 1997's order (the class's
## notes); its dice seeded with [param seed_value], or from the clock when
## −1. Null for no such slot.
static func enter(player: AdventurePlayer, setup: Dictionary, seed_value := -1) -> DungeonBoard:
	var world := player.world if player != null else null
	var at := int(setup.get("index", -1))
	if world == null or at < 0 or at >= mini(world.encounters.size(), WorldClues.SLOTS):
		return null
	var slot: Dictionary = world.encounters[at]
	var board := DungeonBoard.new()
	board.index = at
	board.castle = at < DungeonDoors.CASTLES
	board.color = clampi(int(slot.get("color", setup.get("color", 1))), 1, 5)
	board.rules = int(slot.get("rules", 0))
	board.run["card_in_effect"] = int(slot.get("card_in_effect", -1))
	board.tries = maxi(int(setup.get("tries", 0)), 0)
	board.difficulty = player.difficulty
	if seed_value < 0:
		seed_value = (Time.get_ticks_usec() ^ randi()) & 0xFFFFFFFF
	var dice := MsvcRandom.new(seed_value)
	board.dice = dice
	board.life_pool = 0
	# The floors' looks: written row by row into 13 to a row, read column
	# by column (dE:250–257) — 1997's own transposition, kept.
	board.looks.resize(CELLS)
	for row in HEIGHT:
		for column in WIDTH:
			board.looks[row * HEIGHT + column] = dice.rand() & 3
	if board.castle:
		board.sheet = "dungeon_tiles_" + WorldClues.COLOR_WORDS[board.color]
	else:
		board.tiles = dice.below(3) + 1
		board.sheet = "dungeon_tiles_%d" % board.tiles
	board.monsters = creatures_for(dice, board.color, int(slot.get("monster_flags", 0)), board.castle)
	board._carve(dice, true)
	board.hero = START
	board.facing = START_FACING
	board.reveal(START)
	return board


## THE FIVE CREATURES of a castle ([param castle_too]) or a dungeon of
## colour [param hue] and [param monster_flags], on [param chance]
## (dE:275–344; the class's notes): five [CreatureBook] rows, slot 4 a
## castle's wizard.
static func creatures_for(chance: MsvcRandom, hue: int, monster_flags: int, castle_too: bool) -> Array[int]:
	var out: Array[int] = []
	var large := 2 if monster_flags & LARGE != 0 else 0
	for slot in MONSTERS:
		var row := CreatureBook.LAIR
		var rounds := 0
		while row == CreatureBook.LAIR:
			var tier: int = DUNGEON_TIERS[slot + large]
			if castle_too:
				tier = CASTLE_TIERS[chance.below(CASTLE_TIERS.size())]
				if slot == WIZARD_SLOT:
					tier = CASTLE_FIFTH_TIER
			row = CreatureBook.pick(chance, hue, tier)
			rounds += 1
			if row == CreatureBook.LAIR and rounds >= PICK_ROUNDS:
				row = _first_of(hue, tier)
		if castle_too and slot == WIZARD_SLOT:
			row = CreatureBook.pick(chance, hue, WIZARD_TIER)
			if row == CreatureBook.LAIR:
				row = CreatureBook.castle_row(hue)
		out.append(row)
	return out


## GUARD: colour [param hue]'s first creature of [param tier], else its
## first creature at all.
static func _first_of(hue: int, tier: int) -> int:
	var rows := CreatureBook.of_color(hue)
	for row in rows:
		if CreatureBook.tier(row) == tier:
			return row
	return rows[0] if not rows.is_empty() else CreatureBook.castle_row(hue)


# --------------------------------------------------------------- the maze --

## A MAZE MADE on [param chance] from its state now (the closures' first
## draw next), for a castle ([param castle_too]) or a dungeon, `tries` and
## [param level] the difficulty: the lattice, the closures, the GUARD, the
## rooms' events (the class's notes). The hero on the start. Pure: the
## golden vectors test it. [param guarded] false runs 1997's own loop, at
## most [constant UNGUARDED_MOST] closures, and gives null past them — the
## tests' comparison, never the game's.
static func generate(chance: MsvcRandom, castle_too: bool, times: int, level: int,
		guarded := true) -> DungeonBoard:
	var board := DungeonBoard.new()
	board.castle = castle_too
	board.tries = maxi(times, 0)
	board.difficulty = level
	board.dice = chance
	if not board._carve(chance, guarded):
		return null
	board.hero = START
	board.reveal(START)
	return board


## The closures until the maze is done (dE:383–405), the GUARD watching.
## False only unguarded, past [constant UNGUARDED_MOST].
func _carve(chance: MsvcRandom, guarded: bool) -> bool:
	_lattice()
	var from := _at(ENTRANCE)
	var tried := {}
	var candidates := _candidates()
	attempts = 0
	restarts = 0
	while guarded or attempts < UNGUARDED_MOST:
		attempts += 1
		var gx := chance.below(7) * 2
		var gy := chance.below(6) * 2
		if chance.below(2) != 0:
			gx += 1
		else:
			gy += 1
		var i := gx * HEIGHT + gy
		var was := cells[i]
		cells[i] = 0
		maze_dice = chance.state
		var verdict := _judge(chance, from)
		if verdict == 2:
			return true
		if verdict == 1:
			if was != 0:
				tried.clear()
			continue
		cells[i] = was
		tried[i] = true
		if guarded and _stuck(candidates, tried):
			# GUARD: no closure can mend this maze; the lattice again.
			_lattice()
			tried.clear()
			restarts += 1
	return false


## Whether every open candidate's closure was undone on this grid.
func _stuck(candidates: PackedInt32Array, tried: Dictionary) -> bool:
	for i in candidates:
		if cells[i] != 0 and not tried.has(i):
			return false
	return true


## The cells a closure may draw: x 0–13, y 0–11, one coordinate odd.
static func _candidates() -> PackedInt32Array:
	var out := PackedInt32Array()
	for x in 14:
		for y in 12:
			if (x & 1) + (y & 1) == 1:
				out.append(x * HEIGHT + y)
	return out


## THE LATTICE (dE:345–382): the cells all open but the border, the
## pillars and the four corners; the entrance opened.
func _lattice() -> void:
	cells.resize(CELLS)
	depth.resize(CELLS)
	for x in WIDTH:
		for y in HEIGHT:
			var solid := x == 0 or y == 0 or x >= 14 or y >= 12 or (x & 1 == 0 and y & 1 == 0) \
					or (x < 3 and y < 3) or (x < 3 and y >= 10) or (x >= 12 and y < 3) or (x >= 12 and y >= 10)
			cells[x * HEIGHT + y] = 0 if solid else OPEN
	cells[_at(ENTRANCE)] = OPEN
	depth.fill(0)


## THE MAZE JUDGED (`PopulateDungeonCellEvents`, dE:1643–1783) with the hero
## on cell [param from]: 0 broken, 1 fine with fewer than three dead ends,
## 2 done — the rooms' events then drawn on [param chance].
func _judge(chance: MsvcRandom, from: int) -> int:
	_measure(from)
	var shallowest := 0x63
	var deepest := 0
	var whole := true
	var previous_row := 0
	var dead_ends := 0
	for y in HEIGHT:
		for x in WIDTH:
			var i := x * HEIGHT + y
			if cells[i] == 0 or i == from:
				continue
			if depth[i] == 0:
				whole = false
			if _ways(i) != 1:
				continue
			if depth[i] < DEAD_END_DEPTH or previous_row == y:
				whole = false
			else:
				dead_ends += 1
				previous_row = y
				shallowest = mini(shallowest, depth[i])
				deepest = maxi(deepest, depth[i])
	if not whole:
		return 0
	if dead_ends < DEAD_ENDS:
		return 1
	var every := 5 - mini(tries + difficulty, 3)
	previous_row = 0
	dead_ends = 0
	for y in HEIGHT:
		for x in WIDTH:
			var i := x * HEIGHT + y
			if cells[i] == 0 or i == from:
				continue
			var ways := _ways(i)
			var d := int(depth[i])
			if ways == 1:
				if d >= DEAD_END_DEPTH and previous_row != y:
					dead_ends += 1
					previous_row = y
					cells[i] |= (WIZARD if castle and dead_ends == 1 else TREASURE) << EVENT_SHIFT
			elif (shallowest - d + 1) % every == 0 and d < deepest and d >= EVENT_DEPTH:
				var event := clampi(_toward_zero(d - shallowest, 4) - 2 + chance.below(6) + ways + _corners(i), 0, 6)
				if chance.below(difficulty + 3) == 0:
					event = DICE
				cells[i] |= event << EVENT_SHIFT
	return 2


## `MarkDungeonDistanceFromCell` (dE:1609): the shortest way from cell
## [param from] + 1 into [member depth], by the open cardinal neighbours
## (the same numbers as 1997's relaxing walk); 0 where nothing reaches.
func _measure(from: int) -> void:
	depth.fill(0)
	depth[from] = 1
	var queue := PackedInt32Array([from])
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		for n in [i - 1, i + HEIGHT, i + 1, i - HEIGHT]:
			if _cell(n) != 0 and depth[n] == 0:
				depth[n] = depth[i] + 1
				queue.append(n)


## The open cardinal neighbours of cell [param i] (up, right, down, left).
## A neighbour past the grid's edge reads as 1997's memory did: the next
## column's first cell — the border, solid (only the entrance has one).
func _ways(i: int) -> int:
	return int(_cell(i - 1) != 0) + int(_cell(i + HEIGHT) != 0) + int(_cell(i + 1) != 0) \
			+ int(_cell(i - HEIGHT) != 0)


## The open diagonal neighbours of cell [param i].
func _corners(i: int) -> int:
	return int(_cell(i + HEIGHT - 1) != 0) + int(_cell(i + HEIGHT + 1) != 0) \
			+ int(_cell(i - HEIGHT + 1) != 0) + int(_cell(i - HEIGHT - 1) != 0)


func _cell(i: int) -> int:
	return cells[i] if i >= 0 and i < CELLS else 0


## C's division of [param a] by [param b], toward zero.
static func _toward_zero(a: int, b: int) -> int:
	var q := absi(a) / b
	return -q if a < 0 else q


static func _at(at: Vector2i) -> int:
	return at.x * HEIGHT + at.y


# ----------------------------------------------------------- reading it --

## Whether [param at] lies on the grid.
static func inside(at: Vector2i) -> bool:
	return at.x >= 0 and at.y >= 0 and at.x < WIDTH and at.y < HEIGHT


## The cell's 1997 value, 0 off the grid.
func value(at: Vector2i) -> int:
	return cells[_at(at)] if inside(at) and cells.size() == CELLS else 0


## Whether the cell is open (any value but 0).
func is_open(at: Vector2i) -> bool:
	return value(at) != 0


## The cell's event (0 none, [constant DICE] … [constant WIZARD]).
func event_at(at: Vector2i) -> int:
	return (value(at) & EVENT_MASK) >> EVENT_SHIFT


## Whether the hero has seen the cell.
func seen(at: Vector2i) -> bool:
	return value(at) & SEEN != 0


## The generation's depth of the cell (1 the entrance, 0 unreached or off
## the grid).
func distance(at: Vector2i) -> int:
	return int(depth[_at(at)]) if inside(at) and depth.size() == CELLS else 0


## The floor's look 0–3 (c4's tile variant), read as 1997 read it.
func look(at: Vector2i) -> int:
	return int(looks[_at(at)]) if inside(at) and looks.size() == CELLS else 0


## Whether [param event] is a room of creature slots 0–3.
static func is_room(event: int) -> bool:
	return event >= ROOM_FIRST and event <= ROOM_LAST


## The creature slot of a room's event [param event] (3–6 → 0–3, the
## wizard's 15 → 4), −1 for none.
static func monster_slot(event: int) -> int:
	if is_room(event):
		return event - ROOM_FIRST
	return WIZARD_SLOT if event == WIZARD else -1


## The creature of a room's [param event], its [CreatureBook] row; −1 for
## none.
func room_creature(event: int) -> int:
	var slot := monster_slot(event)
	return monsters[slot] if slot >= 0 and slot < monsters.size() else -1


## The castle's or the dungeon's name (`@DUNGEON_NAMES`).
func title() -> String:
	return WorldNames.dungeon_name(index)


## The card in effect's name ("%s in effect."), "" for none.
func effect_name() -> String:
	return String(WorldClues.EFFECT_CARDS.get(int(run.get("card_in_effect", -1)), ""))


## WHAT IS LEFT ON THE BOARD [ours, the owner's board extras: "show the
## room count left"]: the cells still holding `creatures` (rooms and the
## wizard's), `treasures`, `dice` and `scrolls`, seen or not.
func rooms_left() -> Dictionary:
	var out := {"creatures": 0, "treasures": 0, "dice": 0, "scrolls": 0}
	for i in cells.size():
		var event := (cells[i] & EVENT_MASK) >> EVENT_SHIFT
		if is_room(event) or event == WIZARD:
			out["creatures"] += 1
		elif event == TREASURE:
			out["treasures"] += 1
		elif event == DICE:
			out["dice"] += 1
		elif event == SCROLL:
			out["scrolls"] += 1
	return out


## THE BOARD DRAWN AS TEXT, a row a line (y 0–12): `#` solid, `.` open, `E`
## the entrance, `d` dice, `s` a scroll, `0`–`3` a room of that slot, `T` a
## treasure, `W` the castle wizard — the research's golden vectors' legend.
func as_text() -> Array[String]:
	var out: Array[String] = []
	for y in HEIGHT:
		var line := ""
		for x in WIDTH:
			var at := Vector2i(x, y)
			var event := event_at(at)
			if not is_open(at):
				line += "#"
			elif at == ENTRANCE:
				line += "E"
			elif is_room(event):
				line += str(event - ROOM_FIRST)
			else:
				line += String({0: ".", DICE: "d", SCROLL: "s", TREASURE: "T", WIZARD: "W"}.get(event, "?"))
		out.append(line)
	return out


# ----------------------------------------------------------------- moving --

## SEEN FROM [param at] (`RevealDungeonCellAndNeighbors`, dE:1420–1460): the
## cell itself, and down each of the four ways every open cell up to the
## first wall (walls are never marked). Whether anything new was seen.
func reveal(at: Vector2i) -> bool:
	if not inside(at) or cells.size() != CELLS:
		return false
	var fresh := cells[_at(at)] & SEEN == 0
	cells[_at(at)] |= SEEN
	for way in STEPS:
		var next: Vector2i = at + STEPS[way]
		while inside(next) and cells[_at(next)] != 0:
			if cells[_at(next)] & SEEN == 0:
				fresh = true
			cells[_at(next)] |= SEEN
			next += STEPS[way]
	return fresh


## A STEP [param way] (1, 3, 5, 7; the class's notes): `{kind: "blocked"}` a
## wall (the hero turned), `{kind: "moved", to, revealed}`, `{kind: "event",
## event, to}` — the hero before it, its page to resolve —, `{kind: "out"}`
## the entrance (the pane asks "Leave?", then [method close]); `{kind:
## "busy"}` while an event waits, the board is over, or no such way.
func step(way: int) -> Dictionary:
	if over or pending != NOWHERE or not STEPS.has(way):
		return {"kind": "busy"}
	facing = (way + 1) % 8 + 1
	var to: Vector2i = hero + STEPS[way]
	if not is_open(to):
		return {"kind": "blocked", "to": to}
	if to == ENTRANCE:
		return {"kind": "out", "to": to}
	var event := event_at(to)
	if event != 0:
		pending = to
		if is_room(event) or event == WIZARD:
			code = event
		return {"kind": "event", "event": event, "to": to}
	hero = to
	return {"kind": "moved", "to": to, "revealed": reveal(to)}


## THE KEY'S WAY (1, 3, 5, 7; 0 for none) [the owner's P4 "Modern"]:
## 1997's Home, PgUp, PgDn, End (dE:463–488); the keypad's 7, 9, 3, 1
## whatever NumLock says [QoL]; the arrows and W A S D turned to the
## board's diagonals — up up-left, right up-right, down down-right, left
## down-left [QoL].
static func direction_of_key(keycode: int) -> int:
	match keycode:
		KEY_HOME, KEY_KP_7, KEY_UP, KEY_W:
			return UP_LEFT
		KEY_PAGEUP, KEY_KP_9, KEY_RIGHT, KEY_D:
			return UP_RIGHT
		KEY_PAGEDOWN, KEY_KP_3, KEY_DOWN, KEY_S:
			return DOWN_RIGHT
		KEY_END, KEY_KP_1, KEY_LEFT, KEY_A:
			return DOWN_LEFT
	return 0


## THE MOUSE'S WAY (`QueueDungeonMouseNavigationInput`, dE:1586–1604): by
## the quadrant of [param offset] — the click less the hero's cell anchor,
## in page pixels, y down — right and up +x, right and down +y, left and
## down −x, left and up −y; on the hero itself right and up.
static func direction_toward(offset: Vector2) -> int:
	var right := offset.x >= 0.0
	var up := offset.y <= 0.0
	if right:
		return UP_RIGHT if up else DOWN_RIGHT
	return UP_LEFT if up else DOWN_LEFT


## THE CELL'S ANCHOR on the 640 × 480 page (`ConvertDungeonCellToScreen`,
## dE:1404–1408): the middle of its floor's diamond.
static func cell_to_page(at: Vector2i) -> Vector2i:
	return Vector2i(32 * (at.x + at.y) - 96, 16 * (at.y - at.x) + 272)


## THE CELL UNDER page point [param point] (`ConvertMouseToDungeonCell`,
## dE:1411–1418): the diamond round each anchor, 1997's 16 pixels up
## first. [ours: 1997's divisions went toward zero, which put the top row's
## diamonds (always solid) on the row below; floored, every point lies in
## its own diamond — the exit's test, 1997's one use, is unchanged.] Off
## the grid it may give a cell [method inside] refuses.
static func page_to_cell(point: Vector2) -> Vector2i:
	var u := floori(point.x)
	var v := floori(point.y) - 16
	var half := floori((u + 96) / 2.0)
	return Vector2i(floori((half - (v - 272)) / 32.0), floori((v + half - 272) / 32.0) + 1)


## A CLICK ALONG A CORRIDOR [QoL, the owner's P4]: the ways to step from the
## hero to [param at] along a straight line of open, seen cells — up to the
## first event or the entrance on the way, where the walk stops; a
## neighbour is one step. `[]` when [param at] is not so reachable (a wall
## between, not in line, the hero's own cell, an event waiting).
func walk_toward(at: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var offset := at - hero
	if over or pending != NOWHERE or offset == Vector2i.ZERO or (offset.x != 0 and offset.y != 0):
		return out
	var way := UP_LEFT
	if offset.x > 0:
		way = UP_RIGHT
	elif offset.x < 0:
		way = DOWN_LEFT
	elif offset.y > 0:
		way = DOWN_RIGHT
	var next := hero
	var stopped := false
	while next != at:
		next += STEPS[way]
		if not is_open(next) or not seen(next):
			return [] as Array[int]
		if not stopped:
			out.append(way)
			stopped = event_at(next) != 0 or next == ENTRANCE
	return out


# ----------------------------------------------------------- the events --

## The event cell resolved and passed: it becomes 0x101 and the hero moves
## in and looks round.
func _pass() -> void:
	if pending == NOWHERE:
		return
	cells[_at(pending)] = PASSED
	hero = pending
	_settled()


## The event resolved with the hero pushed back: the hero stays and looks
## round (a new figure in sight).
func _stay() -> void:
	_settled()


func _settled() -> void:
	pending = NOWHERE
	code = 0
	reveal(hero)


## THE DICE (event 1; the class's notes) for [param player]: `{lives, card,
## words}` — `lives` 1–3 into the pool, or `card` put in play in the next
## room duel ([member dice_card]); the hero moves in. `{}` when no dice
## waits.
func roll_dice(player: AdventurePlayer) -> Dictionary:
	if event_at(pending) != DICE:
		return {}
	var lives := 0
	var card := ""
	if dice.rand() & 1 != 0:
		lives = dice.below(3) + 1
	else:
		var usable := dice_cards(player)
		if usable.is_empty():
			# [ours: 1997 slip N2, the owner's D9] no creature or artifact
			# the dice may give: the lives instead of drawing forever.
			lives = dice.below(3) + 1
		else:
			# 1997's draw ([method MsvcRandom.place_among]: never endless
			# past 32,767 cards, the 0.50.65 bug campaign, k1-3).
			var bag := maxi(AdventurePlayer.BAG_MOST, player.cards.size())
			card = String(player.cards[dice.place_among(bag, usable)]["card"])
	if lives > 0:
		life_pool += lives
		dice_lives = lives
		dice_card = ""
	else:
		dice_card = card
		dice_lives = 0
	var words := YOU_GET % (LIVES % [lives, next_duel_life(player)] if lives > 0 else card)
	_pass()
	return {"lives": lives, "card": card, "words": words}


## THE PLACES IN [member AdventurePlayer.cards] the dice may give: the deck
## in use's creatures and artifacts, every copy — [ours: 1997 slip k, the
## owner's k2] none the rules bar ([method bars]).
func dice_cards(player: AdventurePlayer) -> Array[int]:
	var out: Array[int] = []
	for i in player.cards.size():
		var entry := player.cards[i] as Dictionary
		var card_name := String(entry.get("card", ""))
		if not (entry.get("decks", []) as Array).has(player.current_deck) or not CardRegistry.has_card(card_name):
			continue
		var data := CardRegistry.get_card(card_name)
		if (data.is_creature() or data.is_type(Mtg.CardType.ARTIFACT)) and not bars(rules, color, card_name):
			out.append(i)
	return out


## WHETHER RULES [param word] OF A SLOT OF COLOUR [param hue] BAR card
## [param card_name] (dE:756–783): "No %s allowed" (0x10) a card of the
## colour — [ours: 1997 slip j, the owner's j2] any of its colours, so a
## gold card with black is barred by "No Black cards" (1997 matched the
## colour exactly); a land by its land types' colours (a Swamp is black, as
## 1997's table had it); a colourless card never (Black Lotus is
## colourless — the lead's reading: the card's real colour, where 1997's
## table coloured the Lotus black) —; "No artifacts allowed" (0x40) an
## artifact, an artifact creature too; "No instants or interrupts allowed"
## (0x80) an instant. A card the game does not know is never barred. The
## dice's test ([method dice_cards]). One rule for the dice and the duels:
## [method DungeonDuels.bars] decides (the owner's ruling of 2026-10-27 —
## the cards' real colours, dual lands barred, Moxen and the Lotus
## colourless).
static func bars(word: int, hue: int, card_name: String) -> bool:
	return DungeonDuels.bars(card_name, word, hue)


## THE SCROLL'S RIDDLE (event 2), asked once on the board's dice at the
## hero's difficulty ([method CardRiddle.make]): its `{question, answers,
## …}`. With no riddle to ask (no card pool) the scroll is passed and `{}`
## comes back [ours]; `{}` too when no scroll waits.
func riddle(player: AdventurePlayer) -> Dictionary:
	if event_at(pending) != SCROLL:
		return {}
	if asked.is_empty():
		asked = CardRiddle.make(dice, player.difficulty)
		if asked.is_empty():
			_pass()
	return asked


## THE RIDDLE ANSWERED with [param answer] (the button's place):
## `{right, words, card, summoned, creature}` — `words` the verdict
## ("Correct!", "WRONG", "WRONG.  Correct is:"), `card` the riddle's card;
## right, the hero moves in; wrong, the cell turns into a room of slot 3
## ([constant SUMMONED]), `creature` its row, and the hero stays. `{}` when
## no riddle was asked.
func riddle_answered(_player: AdventurePlayer, answer: int) -> Dictionary:
	if asked.is_empty() or event_at(pending) != SCROLL:
		return {}
	var right := CardRiddle.correct(asked, answer)
	var out := {"right": right, "words": CardRiddle.verdict(asked, answer), "card": String(asked.get("card", "")),
		"summoned": not right, "creature": -1}
	asked = {}
	if right:
		_pass()
	else:
		cells[_at(pending)] = SUMMONED
		out["creature"] = room_creature(SUMMONED >> EVENT_SHIFT)
		_stay()
	return out


## A ROOM'S DUEL OVER (events 3–6, or the wizard's 15), its outcome
## [param outcome] from [DungeonDuels] ([constant CLEARED], [constant
## AGAIN], [constant THROWN_OUT], [constant LOST], [constant LEFT],
## [constant BEATEN], [constant GAME_OVER]; the class's notes): `{passed,
## out, booted, beaten}`. The dice's gift is spent by any duel (1997's
## slot cleared after every duel, dE:907); the pool is the duels' to write
## and stays for the next room. `{}` when no room waits or the outcome is
## unknown.
func room_done(_player: AdventurePlayer, outcome: String) -> Dictionary:
	var event := event_at(pending)
	if not (is_room(event) or event == WIZARD):
		return {}
	match outcome:
		CLEARED:
			_pass()
		AGAIN:
			_stay()
		THROWN_OUT, LOST:
			# The room lost: the cell solid, the hero where he stood
			# (dE:559–569; unseen — rule 0x01 ends the visit).
			cells[_at(pending)] = 0
			_stay()
			if outcome == THROWN_OUT or rules & CARRIES != 0:
				over = true
				booted = castle
		LEFT:
			_stay()
			over = true
		BEATEN:
			_stay()
			over = true
			beaten = castle
		GAME_OVER:
			_stay()
			over = true
			game_over = true
		_:
			return {}
	dice_card = ""
	dice_lives = 0
	return {"passed": outcome == CLEARED, "out": over, "booted": booted, "beaten": beaten}


## A TREASURE OPENED (event 7; the class's notes) for [param player]:
## `{card, words, bag_full}` — a card found ("Found This Card": one of the
## dungeon's own, or one the hero left behind on an earlier visit), in the
## bag and out of the dungeon unless `bag_full` (then [method
## treasure_swap] or [method treasure_declined]) — or `{gold, jewels,
## words, bag_full: false}` (`jewels` the amulets by colour name). The hero
## moves in. `{}` when no treasure waits.
func open_treasure(player: AdventurePlayer) -> Dictionary:
	if event_at(pending) != TREASURE or not found.is_empty():
		return {}
	var pool := _treasure_pool(player)
	if not pool.is_empty():
		var entry: Dictionary = pool[dice.below(pool.size())]
		var card_name := String(entry["card"])
		# The full bag of the 1997 card hold ([method AdventurePlayer.bag_room];
		# never under "Unlimited card hold", which offers no swap).
		if player.bag_room() < 1:
			found = entry
			return {"card": card_name, "words": FOUND_CARD, "bag_full": true}
		_take(player, entry)
		_pass()
		return {"card": card_name, "words": FOUND_CARD, "bag_full": false}
	var gold := dice.below(100) * (difficulty + 2) + 100
	gold -= gold % 10
	player.gold += gold
	var jewels := {}
	var lines: Array[String] = []
	for hue in AdventurePlayer.COLORS.size():
		var count := dice.below(2)
		if count == 0:
			continue
		var color_name: String = AdventurePlayer.COLORS[hue]
		jewels[color_name] = count
		player.amulets[color_name] = int(player.amulets.get(color_name, 0)) + count
		lines.append(JEWELS[hue] % count)
	player.log_event("treasure", "", {"slot": index, "gold": gold})
	_pass()
	var words := FOUND_JEWELS % [gold, "\n".join(lines)] if not lines.is_empty() else FOUND_GOLD % gold
	return {"gold": gold, "jewels": jewels, "words": words, "bag_full": false}


## THE SWAP for a card found with a full bag [ours, the owner's D12]: the
## hero's card at [param give_up] ([member AdventurePlayer.cards]) left
## behind — out of the bag and every deck, and INTO THE DUNGEON as its
## treasure, to be found again on a later visit (the owner's ruling of
## 2026-10-27; the class's notes) — and the found card taken: `{card,
## left}`; the hero moves in. `{}` when no card waits or no such card is the
## hero's.
func treasure_swap(player: AdventurePlayer, give_up: int) -> Dictionary:
	if found.is_empty() or give_up < 0 or give_up >= player.cards.size():
		return {}
	var left := String((player.cards[give_up] as Dictionary).get("card", ""))
	player.cards.remove_at(give_up)
	var card_name := String(found["card"])
	_take(player, found)
	_leave_behind(player, left)
	found = {}
	_pass()
	return {"card": card_name, "left": left}


## THE SWAP DECLINED [ours, the owner's D12, the lead's reading]: the card
## found stays in the dungeon for a later visit, the dead end is passed:
## `{card}`. `{}` when no card waits.
func treasure_declined(_player: AdventurePlayer) -> Dictionary:
	if found.is_empty():
		return {}
	var card_name := String(found["card"])
	found = {}
	_pass()
	return {"card": card_name}


## The world's slot of this board, live (`{}` for none).
func _slot(player: AdventurePlayer) -> Dictionary:
	var world := player.world if player != null else null
	if world == null or index < 0 or index >= world.encounters.size():
		return {}
	return world.encounters[index]


## THE CARDS A DEAD END MAY GIVE NOW, alike in chance: `{card, treasure}`
## for each of the dungeon's own ([constant ShandalarWorld.DUNGEON_CARDS]
## index) and `{card, left: true}` for each the hero left behind in it —
## but those left on this visit ([member left_here]), which wait for a later
## one.
func _treasure_pool(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slot := _slot(player)
	for treasure in slot.get("cards", []):
		out.append({"card": String(ShandalarWorld.DUNGEON_CARDS[int(treasure)][1]), "treasure": int(treasure)})
	var waiting := left_here.duplicate()
	for card_name in WorldClues.left_cards(slot):
		if card_name in waiting:
			waiting.erase(card_name)
			continue
		out.append({"card": card_name, "left": true})
	return out


## Treasure [param entry] ([method _treasure_pool]'s) out of the dungeon and
## into the bag, in no deck (1997: the journal's type 19, then
## `AddCardToDeckSorted` — "Acquired spell" for its rarity).
func _take(player: AdventurePlayer, entry: Dictionary) -> void:
	var slot := _slot(player)
	var card_name := String(entry.get("card", ""))
	if entry.has("treasure"):
		var held: Array = slot.get("cards", [])
		var at := held.find(int(entry["treasure"]))
		if at >= 0:
			held.remove_at(at)
	elif not slot.is_empty():
		var kept := WorldClues.left_cards(slot)
		kept.erase(card_name)
		slot[WorldClues.LEFT_CARDS] = kept
	player.log_event("treasure", "", {"slot": index, "card": card_name})
	player.add_card(card_name)


## Card [param card_name] left behind in the dungeon as its treasure (the
## swap; the class's notes), waiting for a later visit.
func _leave_behind(player: AdventurePlayer, card_name: String) -> void:
	var slot := _slot(player)
	if card_name == "" or slot.is_empty():
		return
	var kept := WorldClues.left_cards(slot)
	kept.append(card_name)
	slot[WorldClues.LEFT_CARDS] = kept
	left_here.append(card_name)


# ----------------------------------------------------- the next duel --

## THE LIFE THE NEXT ROOM DUEL STARTS WITH for [param player] (the class's
## notes): the mana links + the lives carried + the world's lives gift + the
## pool.
func next_duel_life(player: AdventurePlayer) -> int:
	return life_in_next_duel(player, run)


## The same, for any run record [param record] ([member run]) — the duels'
## own sum ([method DungeonDuels.hero_life]), one rule for both.
static func life_in_next_duel(player: AdventurePlayer, record: Dictionary) -> int:
	return DungeonDuels.hero_life(player, record)


## THE LINE UNDER THE TITLE (`AppendDungeonRewardDescription`,
## dE:1529–1549; c4 draws it): what the next room duel brings — "+%d (%d)
## Lives" (the dice's lives and the world's gift, and the life the duel
## starts with), the cards put in play (the world's, then the dice's — the
## duel puts both, [DungeonDuels]), "First Move" (the world's) — joined by
## ", "; "" for nothing.
func next_duel_line(player: AdventurePlayer) -> String:
	var parts: Array[String] = []
	var lives := dice_lives + player.next_duel_life
	if lives != 0:
		parts.append(LIVES % [lives, next_duel_life(player)])
	for card in [player.next_duel_card, dice_card]:
		if String(card) != "":
			parts.append(String(card))
	if player.next_duel_first_move:
		parts.append(FIRST_MOVE)
	return ", ".join(parts)


# -------------------------------------------------------------- leaving --

## THE BOARD LEFT (the class's notes), whatever the way out: `{index,
## beaten, booted, game_over, words}` — `words` the booted lines of a castle
## left after a lost room — for [method DungeonDoors.leave] and the world
## screen's seam. The pool and the dice's card spent; the world's gifts
## kept.
func close(_player: AdventurePlayer) -> Dictionary:
	over = true
	var words: Array[String] = []
	if castle and booted and color >= 1 and color <= WorldNames.WIZARDS.size():
		words.append(BOOTED % WorldNames.WIZARDS[color - 1])
	life_pool = 0
	dice_card = ""
	dice_lives = 0
	code = 0
	pending = NOWHERE
	asked = {}
	found = {}
	return {"index": index, "beaten": beaten, "booted": booted, "game_over": game_over, "words": words}
