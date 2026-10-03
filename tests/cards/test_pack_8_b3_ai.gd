extends GameTest
## Pack 8, batch B3 — the fair AI on a board of this batch's creatures.
## Every card-local effect class in cards/sets/mir/_creatures.gd is read by
## EffectIntent, simulated by the tactical planner (the colour changes) and
## offered through the expansion tactics; two AI seats playing the board
## for several turns must neither stall nor raise a script error (the gate
## fails on any ERROR line), and the abilities must actually be used.

const MINE := ["Femeref Healer", "Civic Guildmage", "Abyssal Hunter", "Reckless Embermage",
	"Tainted Specter", "Locust Swarm", "Hakim, Loreweaver", "Wave Elemental", "Ersatz Gnomes",
	"Raging Spirit", "Sawback Manticore", "Jungle Patrol", "Zirilan of the Claw",
	"Goblin Tinkerer", "Uktabi Wildcats", "Maro", "Kukemssa Serpent", "Ethereal Champion",
	"Pearl Dragon", "Azimaet Drake", "Flame Elemental", "Burning Palm Efreet", "Rashida Scalebane"]
const THEIRS := ["Femeref Archers", "Unyaro Griffin", "Daring Apprentice", "Vigilant Martyr",
	"Spectral Guardian", "Suq'Ata Firewalker", "Shadow Guildmage", "Granger Guildmage",
	"Barbed-Back Wurm", "Urborg Panther", "Wall of Corpses", "Hivis of the Scale",
	"Pyric Salamander", "Mire Shade", "Sewer Rats", "Blighted Shaman", "Dwarven Miner",
	"Leering Gargoyle", "Canopy Dragon", "Village Elder", "Foratog", "Crimson Hellkite",
	"Goblin Soothsayer", "Shauku's Minion", "Subterranean Spirit", "Haunting Apparition"]
const LANDS := ["Plains", "Island", "Swamp", "Mountain", "Forest"]


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int, names: Array) -> void:
	for land in LANDS:
		for n in 3: put_battlefield(pid, land)
	put_battlefield(pid, "Sol Ring")
	put_battlefield(pid, "Crusade")
	for card_name in names: put_battlefield(pid, card_name)
	for card_name in ["Lightning Bolt", "Giant Growth", "Grizzly Bears", "Holy Strength"]:
		give_hand(pid, card_name)
	var dragon := give_hand(pid, "Shivan Dragon")
	g.put_from_hand_on_top_of_library(dragon)


func test_two_ai_seats_play_a_board_of_mirage_creatures() -> void:
	var a := AiPlayer.new(0, AiProfile.wizard())
	var b := AiPlayer.new(1, AiProfile.wizard())
	g.set_agent(0, a)
	g.set_agent(1, b)
	_seat(0, MINE)
	_seat(1, THEIRS)
	var guard := 0
	while g.turn_number < 8 and not g.game_over and guard < 4000:
		if a.act(g) == "" and b.act(g) == "":
			break
		guard += 1
	assert_true(g.turn_number >= 8 or g.game_over,
		"the duel moved on (turn %d, %d actions)" % [g.turn_number, guard])
	var activations := 0
	for line in g.log_lines:
		if String(line).contains(" activates "): activations += 1
	assert_gt(activations, 0, "the pilots used the batch's abilities")
