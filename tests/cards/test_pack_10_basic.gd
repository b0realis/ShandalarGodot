extends GameTest
## Pack 10 (the Urza block), the `_basic` family of cards/sets/{usg,ulg,uds}:
## the vanilla and keyword-only creatures complete from the first day. Each
## is cast through the public API and arrives with exactly the keywords,
## landwalk and protection its Oracle text prints; a flash creature is cast
## in the opponent's turn, a vanilla one in the controller's main phase.

## [name, keywords, landwalk, protection] for every name `_basic` claims.
const CLAIMED := [
	["Argothian Swine", [Mtg.Keyword.TRAMPLE], [], 0],
	["Blanchwood Treefolk", [], [], 0],
	["Coral Merfolk", [], [], 0],
	["Crazed Skirge", [Mtg.Keyword.FLYING, Mtg.Keyword.HASTE], [], 0],
	["Goblin Spelunkers", [], ["mountain"], 0],
	["Guma", [], [], Mtg.ManaColor.U],
	["Pegasus Charger", [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE], [], 0],
	["Serra Zealot", [Mtg.Keyword.FIRST_STRIKE], [], 0],
	["Thundering Giant", [Mtg.Keyword.HASTE], [], 0],
	["Voice of Grace", [Mtg.Keyword.FLYING], [], Mtg.ManaColor.B],
	["Voice of Law", [Mtg.Keyword.FLYING], [], Mtg.ManaColor.R],
	["Defender of Chaos", [Mtg.Keyword.FLASH], [], Mtg.ManaColor.W],
	["Defender of Law", [Mtg.Keyword.FLASH], [], Mtg.ManaColor.R],
	["Giant Cockroach", [], [], 0],
	["Plague Beetle", [], ["swamp"], 0],
	["Weatherseed Faeries", [Mtg.Keyword.FLYING], [], Mtg.ManaColor.R],
	["Yavimaya Wurm", [Mtg.Keyword.TRAMPLE], [], 0],
	["Goblin Berserker", [Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.HASTE], [], 0],
	["Goliath Beetle", [Mtg.Keyword.TRAMPLE], [], 0],
	["Plated Spider", [Mtg.Keyword.REACH], [], 0],
	["Squirming Mass", [Mtg.Keyword.FEAR], [], 0],
	["Tormented Angel", [Mtg.Keyword.FLYING], [], 0],
	["Voice of Duty", [Mtg.Keyword.FLYING], [], Mtg.ManaColor.G],
	["Voice of Reason", [Mtg.Keyword.FLYING], [], Mtg.ManaColor.U],
	["Wild Colos", [Mtg.Keyword.HASTE], [], 0],
]

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


## Enough of every color for any of these costs (none is above seven).
func _plenty(pid: int) -> void:
	for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]:
		add_mana(pid, color, 7)


func test_every_basic_creature_is_cast_with_its_printed_keywords() -> void:
	for row in CLAIMED:
		var name := String(row[0])
		var card := give_hand(0, name)
		_plenty(0)
		assert_ok(g.cast_spell(0, card))
		resolve_stack()
		assert_eq(card.zone, Mtg.Zone.BATTLEFIELD, name)
		var wanted: Array = row[1]
		for keyword in wanted:
			assert_true(card.has_keyword(keyword), "%s has keyword %d" % [name, keyword])
		for keyword in [Mtg.Keyword.FLYING, Mtg.Keyword.FIRST_STRIKE, Mtg.Keyword.TRAMPLE,
				Mtg.Keyword.HASTE, Mtg.Keyword.REACH, Mtg.Keyword.FEAR, Mtg.Keyword.FLASH,
				Mtg.Keyword.DEFENDER, Mtg.Keyword.VIGILANCE]:
			if not wanted.has(keyword):
				assert_false(card.has_keyword(keyword), "%s has no keyword %d" % [name, keyword])
		assert_eq(Array(card.cur_landwalk), row[2], name)
		assert_eq(card.cur_protection, int(row[3]), name)
		assert_eq([card.cur_power, card.cur_toughness], [card.data.power, card.data.toughness], name)
		g.players[0].mana_pool.clear()


func test_a_flash_defender_is_cast_in_the_opponents_turn() -> void:
	advance_to_next_turn()   # the opponent's main phase
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var bear := give_hand(0, "Coral Merfolk")
	var law := give_hand(0, "Defender of Law")
	add_mana(0, Mtg.ManaColor.U, 2)
	assert_refused(g.cast_spell(0, bear), "")
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, law))
	resolve_stack()
	assert_eq(law.zone, Mtg.Zone.BATTLEFIELD)


func test_protection_from_red_stops_a_red_spell() -> void:
	var law := put_battlefield(0, "Defender of Law")
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	g.priority_player = 1
	assert_refused(g.cast_spell(1, bolt, [TargetRef.card(law)]), "")
	assert_eq(law.zone, Mtg.Zone.BATTLEFIELD)
	# Control: the same Bolt is a legal spell at a creature without it.
	var merfolk := put_battlefield(0, "Coral Merfolk")
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(merfolk)]))
	resolve_stack()
	assert_eq(merfolk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(law.zone, Mtg.Zone.BATTLEFIELD)
