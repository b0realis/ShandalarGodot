extends GutTest
## THE 1997 DECKS, PORTED — `decks/1997/<group>/`, `decks/tournament/`,
## `decks/community/` and `decks/extended_community/` (`docs/decks-1997.md`):
## every deck group the mtg.wiki preconstructed-decks page lists for the
## MicroProse game, plus the period's tournament lists, the community's
## own decks and the Old School reference lists, shipped as `.deck` files
## on 2026-09-02.
##
## What is pinned is the PORT, not the cards: that every file loads
## through the real loader with no parse error, that each group holds
## exactly the number of decks its sources yielded, that every MicroProse
## deck is proxy-free (so a gauntlet can deal it), that the non-MicroProse
## decks are proxied exactly as their tables say (so nothing pretends a
## card exists), and that adding 312 files under `decks/` moved none of
## the defaults the rest of the project pins — `all_deck_paths()[0]` is
## still Big Green, and the Deck Lab's default field is still the five
## starter decks.
##
## THE SNAPSHOTS ([constant PROXY_FREE], [constant PROXIED]) are the
## proxied-card tables of `docs/decks-1997.md` as the loader sees them.
## They are MEANT to fail when a card in them gets implemented: that is
## the moment to strike the name from the table and from the snapshot,
## both — and to move the deck that just became proxy-free into
## [constant PROXY_FREE], because the gauntlet will deal it from then on.


## No trailing slash: [method DeckStore.deck_paths_in] joins with one.
const ROOT := "res://decks/1997"

## folder -> [heading, deck count] — the MicroProse groups, the counts
## the sources yielded (`docs/decks-1997.md` says where each came from
## and what the wiki claims instead).
const GROUPS := {
	"originals": [DeckGroups.ORIGINALS, 55],
	"ancients": [DeckGroups.ANCIENTS, 55],
	"duels": [DeckGroups.PLANESWALKERS, 25],
	"coyote_tex": [DeckGroups.COYOTE_TEX, 5],
	"kevin_bane": [DeckGroups.KEVIN_BANE, 8],
	"other": [DeckGroups.OTHER, 9],
}
const MICROPROSE_TOTAL := 157
## folder -> [heading, deck count, the header word for who made it] — the
## three non-MicroProse groups, each its own folder under `decks/`.
const NON_MICROPROSE := {
	"tournament": [DeckGroups.TOURNAMENT, 76, "pilot:"],
	"community": [DeckGroups.COMMUNITY, 64, "designer:"],
	"extended_community": [DeckGroups.EXTENDED_COMMUNITY, 15, "designer:"],
}
const PORTED_TOTAL := 312
## The enemy-deck groups: one deck per enemy, each with a `# tier:` line.
const ENEMY_GROUPS := ["originals", "ancients", "duels"]

## folder -> the files of that group the pool holds every card of, sorted
## — the decks a gauntlet deals. Everything else in the folder holds at
## least one proxy.
const PROXY_FREE := {
	"tournament": [
		"ec2015_beckert.deck", "noobcon2014_stalin.deck",
		"noobcon2016_berlin.deck", "wc1994_bulmahn.deck", "wc1994_rosewater.deck"
	],
	"community": [
		"explosion_wright_1994.deck", "lich_baxter_1995.deck",
		"proto_zoo_edwards.deck", "sargent_2009_ape_lord.deck",
		"sargent_2009_arch_angel.deck", "sargent_2009_astral_visionary.deck",
		"sargent_2009_azaar.deck", "sargent_2009_beast_master.deck",
		"sargent_2009_cleric.deck", "sargent_2009_conjurer.deck",
		"sargent_2009_crusader.deck", "sargent_2009_druid.deck",
		"sargent_2009_elvish_magi.deck", "sargent_2009_enchantress.deck",
		"sargent_2009_forest_dragon.deck", "sargent_2009_goblin_warlord.deck",
		"sargent_2009_high_priest.deck", "sargent_2009_hydra.deck",
		"sargent_2009_kyzzn.deck", "sargent_2009_merfolk_shaman.deck",
		"sargent_2009_mind_stealer.deck", "sargent_2009_morgane.deck",
		"sargent_2009_necromancer.deck", "sargent_2009_nether_fiend.deck",
		"sargent_2009_paladin.deck", "sargent_2009_priestess.deck",
		"sargent_2009_sainted_one.deck", "sargent_2009_sea_dragon.deck",
		"sargent_2009_sedge_beast.deck", "sargent_2009_seer.deck",
		"sargent_2009_shapeshifter.deck", "sargent_2009_sorcerer.deck",
		"sargent_2009_sorceress.deck", "sargent_2009_summoner.deck",
		"sargent_2009_thought_invoker.deck", "sargent_2009_troll_shaman.deck",
		"sargent_2009_tusk_guardian.deck", "sargent_2009_undead_knight.deck",
		"sargent_2009_vampire_lord.deck", "sargent_2009_war_mage.deck",
		"sargent_2009_winged_stallion.deck", "sargent_2009_witch.deck",
		"the_deck_weissman_1994_95_winter.deck",
		"the_deck_weissman_1994_fall.deck", "the_deck_weissman_1996_02.deck",
		"the_deck_weissman_1996_summer.deck", "turn_one_terror_hyra_1995.deck",
		"twist_of_fire_merritt_1993.deck"
	],
	"extended_community": [
		"os_workshop_aggro_menendian.deck"
	],
}

## folder -> {a name the pool does not hold: how many of that group's decks
## want it} — the proxied-card table of `docs/decks-1997.md`, per group.
const PROXIED := {
	"tournament": {
		"Abbey Gargoyles": 3, "Abduction": 1, "Abeyance": 6, "Adarkar Wastes": 13,
		"Aeolipile": 5, "An-Zerrin Ruins": 1, "Anarchy": 11, "Apocalypse Chime": 2,
		"Arcane Denial": 7, "Arenson's Aura": 2, "Aura of Silence": 1,
		"Autumn Willow": 5, "Aysen Bureaucrats": 1, "Balduvian Trading Post": 1,
		"Barbed Sextant": 1, "Binding Grasp": 2, "Blinking Spirit": 5,
		"Bottomless Vault": 1, "Bounty of the Hunt": 1, "Brainstorm": 2,
		"Brushland": 10, "Chaos Orb": 7, "Choking Sands": 4, "City of Solitude": 2,
		"Cloud Elemental": 1, "Coercion": 1, "Contagion": 10, "Crypt Rats": 1,
		"Dance of the Dead": 3, "Dark Banishing": 7, "Deadly Insect": 6,
		"Death Spark": 1, "Death Speakers": 1, "Deflection": 1,
		"Demonic Consultation": 9, "Despotic Scepter": 4, "Diminishing Returns": 1,
		"Disrupt": 1, "Dissipate": 6, "Dwarven Catapult": 2, "Dwarven Hold": 1,
		"Dwarven Miner": 2, "Dwarven Ruins": 4, "Dwarven Soldier": 1,
		"Dystopia": 11, "Ebon Stronghold": 2, "Ebony Charm": 1, "Elkin Bottle": 3,
		"Emerald Charm": 2, "Empyrial Armor": 1, "Energy Storm": 4,
		"Enlightened Tutor": 6, "Equipoise": 1, "Eron the Relentless": 3,
		"Essence Filter": 2, "Exile": 3, "Fallen Askari": 2, "Fire Diamond": 1,
		"Fireblast": 3, "Force of Will": 10, "Forsaken Wastes": 4,
		"Frenetic Efreet": 3, "Fyndhorn Elves": 6, "Gemstone Mine": 3,
		"Gerrard's Wisdom": 1, "Glacial Crevasses": 1, "Goblin Mutant": 1,
		"Goblin Tinkerer": 1, "Goblin Vandal": 1, "Gorilla Shaman": 4,
		"Granger Guildmage": 1, "Grassland": 1, "Guerrilla Tactics": 5,
		"Hall of Gemstone": 1, "Hallowed Ground": 2, "Hammer of Bogardan": 8,
		"Harvest Wurm": 1, "Havenwood Battleground": 3, "Heart of Yavimaya": 1,
		"Honorable Passage": 4, "Hydroblast": 11, "Hymn to Tourach": 12,
		"Icatian Town": 1, "Icequake": 3, "Ihsan's Shade": 5, "Illumination": 1,
		"Impulse": 4, "Incinerate": 24, "Infernal Darkness": 9, "Jester's Cap": 10,
		"Jeweled Amulet": 1, "Johtull Wurm": 1, "Jokulhaups": 5,
		"Jolrael's Centaur": 3, "Kaervek's Spite": 1, "Kaervek's Torch": 3,
		"Karplusan Forest": 12, "Kjeldoran Outpost": 13, "Knight of Stromgald": 10,
		"Knight of the Mists": 2, "Lake of the Dead": 3, "Land Cap": 2,
		"Lava Hounds": 1, "Lava Tubes": 3, "Lhurgoyf": 6, "Lim-Dûl's Vault": 1,
		"Lodestone Bauble": 4, "Man-o'-War": 3, "Mangara's Blessing": 1,
		"Marble Diamond": 5, "Martyrdom": 1, "Memory Lapse": 1, "Mind Bend": 1,
		"Mind Stone": 1, "Mind Warp": 2, "Moss Diamond": 2, "Mountain Valley": 1,
		"Mystical Tutor": 6, "Necratog": 2, "Necropotence": 11, "Nekrataal": 3,
		"Ophidian": 1, "Orcish Cannoneers": 1, "Orcish Librarian": 2,
		"Orcish Lumberjack": 1, "Orcish Spy": 1, "Order of Leitbur": 8,
		"Order of the Ebon Hand": 7, "Order of the White Shield": 6, "Orgg": 6,
		"Pacifism": 1, "Pale Bears": 1, "Phyrexian Furnace": 5,
		"Phyrexian War Beast": 2, "Pillage": 8, "Political Trickery": 7,
		"Primitive Justice": 1, "Prismatic Ward": 1, "Pygmy Allosaurus": 1,
		"Pyroblast": 22, "Pyroclasm": 8, "Pyrokinesis": 4, "Quicksand": 4,
		"Quirion Ranger": 1, "Rainbow Efreet": 2, "Ray of Command": 1,
		"Reinforcements": 1, "Reprisal": 1, "Ring of Renewal": 1, "River Boa": 1,
		"River Delta": 1, "Rogue Elephant": 1, "Ruins of Trokair": 8,
		"Sand Golem": 2, "Sea Sprite": 3, "Seeds of Innocence": 2, "Serenity": 2,
		"Serrated Arrows": 29, "Shadow Guildmage": 2, "Sheltered Valley": 1,
		"Sky Diamond": 2, "Snow-Covered Mountain": 1, "Snow-Covered Plains": 1,
		"Snow-Covered Swamp": 1, "Soldevi Digger": 1, "Soldevi Excavations": 1,
		"Soul Burn": 3, "Soul Echo": 1, "Spectral Bears": 5,
		"Squandered Resources": 1, "Steel Golem": 1, "Stench of Decay": 1,
		"Storm Shaman": 1, "Stormbind": 10, "Straw Golem": 1, "Stromgald Cabal": 2,
		"Stupor": 3, "Sulfurous Springs": 6, "Sunstone": 1, "Suq'Ata Lancer": 3,
		"Svyelunite Temple": 2, "Thawing Glaciers": 12, "Tidal Wave": 1,
		"Timberline Ridge": 1, "Tithe": 3, "Torture": 1, "Tranquil Domain": 3,
		"Truce": 1, "Uktabi Orangutan": 2, "Underground River": 4,
		"Undiscovered Paradise": 7, "Viashino Sandstalker": 2,
		"Wildfire Emissary": 6, "Withering Wisps": 1, "Wizards' School": 1,
		"Woolly Spider": 1, "Zur's Weirding": 1, "Zuran Orb": 42
	},
	"community": {
		"Adarkar Wastes": 1, "An-Zerrin Ruins": 1, "Arcane Denial": 1,
		"Bounty of the Hunt": 1, "Chaos Orb": 3, "Dark Banishing": 1,
		"Despotic Scepter": 1, "Dwarven Lieutenant": 1, "Dwarven Miner": 1,
		"Dwarven Ruins": 1, "Dwarven Trader": 1, "Force of Will": 3,
		"Forgotten Lore": 1, "Fyndhorn Elves": 1, "Gorilla Shaman": 2,
		"Harvest Wurm": 1, "Heart of Yavimaya": 1, "Hydroblast": 3,
		"Hymn to Tourach": 2, "Icequake": 1, "Ihsan's Shade": 1, "Incinerate": 1,
		"Jester's Cap": 1, "Jolrael's Centaur": 1, "Lhurgoyf": 1,
		"Lim-Dûl's Vault": 1, "Lodestone Bauble": 1, "Merchant Scroll": 1,
		"Mesmeric Trance": 1, "Mystical Tutor": 2, "Necropotence": 2,
		"Orcish Cannoneers": 1, "Orcish Librarian": 1, "Order of the Ebon Hand": 1,
		"Pyroblast": 4, "Quirion Ranger": 1, "Rogue Elephant": 1, "Sand Golem": 1,
		"Serrated Arrows": 1, "Spectral Bears": 1, "Uktabi Orangutan": 1,
		"Underground River": 1, "Vampiric Tutor": 1, "Zuran Orb": 9
	},
	"extended_community": {
		"Ashen Ghoul": 2, "Chaos Orb": 13, "Crimson Hellkite": 1,
		"Dance of the Dead": 1, "Deep Spawn": 2, "Demonic Consultation": 1,
		"Forgotten Lore": 1, "Glacial Chasm": 1, "Hydroblast": 1,
		"Hymn to Tourach": 1, "Incinerate": 1, "Jester's Cap": 1,
		"Krovikan Horror": 1, "Necromancy": 1, "Polar Kraken": 1, "Pyroblast": 1,
		"Shallow Grave": 1, "Underground River": 1, "Vampiric Tutor": 1,
		"Zur's Weirding": 1, "Zuran Orb": 1
	},
}


func _paths(folder: String) -> Array[String]:
	return DeckStore.deck_paths_in(ROOT + "/" + folder)


func _group_paths(folder: String) -> Array[String]:
	return DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR + "/" + folder)


func _text(path: String) -> String:
	return DeckStore.read_text(path)


func _header_has(path: String, key: String) -> bool:
	for line in _text(path).split("\n"):
		if line.begins_with("# " + key):
			return true
	return false


func _proxy_free_total() -> int:
	var total := 0
	for folder in PROXY_FREE:
		total += (PROXY_FREE[folder] as Array).size()
	return total


# ================================================================ counts ==

func test_each_group_holds_exactly_the_decks_its_sources_yielded() -> void:
	var total := 0
	for folder in GROUPS:
		var paths := _paths(folder)
		assert_eq(paths.size(), GROUPS[folder][1], folder)
		total += paths.size()
	assert_eq(total, MICROPROSE_TOTAL)
	for folder in NON_MICROPROSE:
		var paths := _group_paths(folder)
		assert_eq(paths.size(), NON_MICROPROSE[folder][1], folder)
		total += paths.size()
	assert_eq(total, PORTED_TOTAL)
	assert_eq(DeckStore.shipped_subfolder_paths().size(), PORTED_TOTAL,
		"and the store walks exactly those")


func test_the_ported_folders_are_the_only_subfolders() -> void:
	var expected: Array[String] = []
	for folder in GROUPS:
		expected.append(ROOT + "/" + folder)
	expected.sort()
	assert_eq(DeckStore.subfolders_of(ROOT), expected)
	var top: Array[String] = [ROOT]
	for folder in NON_MICROPROSE:
		top.append(DeckStore.SHIPPED_DIR + "/" + folder)
	top.sort()
	assert_eq(DeckStore.subfolders_of(DeckStore.SHIPPED_DIR), top)


# ============================================================== loading ==

func test_every_ported_deck_loads_with_no_parse_error() -> void:
	# The REAL loader, leniently — an unknown name becomes a proxy and is
	# never dropped, which is the whole reason the non-MicroProse decks
	# can ship at all. Sizes: nothing under the forty a duel needs (two
	# period lists ARE forty — Edwards' Proto-Zoo, Merritt's Twist of
	# Fire — and say so in their headers), nothing over the caps the
	# gauntlet checks.
	var seen := 0
	for path in DeckStore.shipped_subfolder_paths():
		var deck := DeckList.load_file(path, false)
		assert_eq(deck.errors, [], path)
		assert_gte(deck.cards.size(), DeckModel.MIN_CARDS, path)
		assert_lte(deck.cards.size(), DeckModel.MAX_TOTAL, path)
		assert_ne(deck.deck_name, "", path)
		assert_ne(deck.deck_name, path.get_file().get_basename(),
			"%s carries its own `name:` line" % path)
		var report: Array = []
		assert_not_null(DeckStore.load_deck(path, report),
			"the Deck Builder opens %s" % path)
		seen += 1
	assert_eq(seen, PORTED_TOTAL)


func test_every_ported_deck_declares_the_group_its_folder_files_it_under() -> void:
	for folder in GROUPS:
		for path in _paths(folder):
			assert_eq(DeckGroups.of(path), GROUPS[folder][0], path)
	for folder in NON_MICROPROSE:
		for path in _group_paths(folder):
			assert_eq(DeckGroups.of(path), NON_MICROPROSE[folder][0], path)


func test_every_ported_deck_carries_its_provenance_in_its_header() -> void:
	# The brief: "each deck carries original name, tier/owner, source
	# citation in header". A `# source:` line names the file or page it
	# came from with its provenance tier; enemy decks carry the tier
	# table's row; the non-MicroProse decks name their pilot (tournament)
	# or designer (the other two), their year, and say in so many words
	# that they are NOT MicroProse decks.
	for folder in GROUPS:
		for path in _paths(folder):
			assert_true(_header_has(path, "source:"), "%s cites a source" % path)
			assert_true(_header_has(path, "designer:"), "%s names its designer" % path)
			if folder in ENEMY_GROUPS:
				assert_true(_header_has(path, "tier:"), "%s carries its tier" % path)
				assert_true(_header_has(path, "enemy:"), "%s names its enemy" % path)
				assert_true(_header_has(path, "variant:"), "%s names its variant" % path)
	for folder in NON_MICROPROSE:
		for path in _group_paths(folder):
			assert_true(_header_has(path, "source:"), "%s cites a source" % path)
			assert_true(_header_has(path, NON_MICROPROSE[folder][2]),
				"%s names who made it" % path)
			assert_true(_header_has(path, "year:"), "%s dates itself" % path)
			assert_true(_text(path).contains("not a MicroProse deck"),
				"%s says whose it is not" % path)
			if folder == "tournament":
				assert_true(_header_has(path, "event:"), "%s names its event" % path)
				assert_true(_header_has(path, "place:"), "%s states its placing" % path)


func test_the_enemy_tier_line_is_the_wiki_tables_row() -> void:
	# `# tier: N/12 <heading> — <life> life, bribe <gold> gold`, N in 1..12.
	# Arzakon's life is set by the difficulty and he cannot be bribed.
	var tiers := {}
	for folder in ENEMY_GROUPS:
		for path in _paths(folder):
			var found := false
			for line in _text(path).split("\n"):
				if line.begins_with("# tier: "):
					var tier := int(line.substr(8).split("/")[0])
					assert_between(tier, 1, 12, path)
					tiers[tier] = true
					found = true
			assert_true(found, path)
	assert_eq(tiers.size(), 12, "every tier of the table is represented")


# ============================================================== proxies ==

func test_every_microprose_deck_is_proxy_free_and_gauntlet_legal() -> void:
	# A strict load is the gauntlet's own test ([method
	# GauntletState.opponent_deck_problem]) — and the point of the port:
	# the 1997 enemies can be met again with the decks they actually had.
	for folder in GROUPS:
		for path in _paths(folder):
			var strict := DeckList.load_file(path, true)
			assert_eq(strict.errors, [], path)
			assert_eq(GauntletState.opponent_deck_problem(path, strict), "", path)


func test_the_non_microprose_decks_are_proxied_exactly_as_the_tables_say() -> void:
	# The snapshot, per group: which files the pool holds whole (the
	# gauntlet deals those, and only those), and for every other name
	# the pool does not hold, how many of the group's decks want it —
	# the proxied-card tables of `docs/decks-1997.md`. Implement one of
	# these cards and this fails: strike it from the table and from here.
	for folder in NON_MICROPROSE:
		var free: Array[String] = []
		var proxied := {}
		for path in _group_paths(folder):
			var deck := DeckList.load_file(path, false)
			var names := {}
			for proxy_name in deck.proxies:
				names[proxy_name] = true
			if names.is_empty():
				free.append(path.get_file())
				var strict := DeckList.load_file(path, true)
				assert_eq(GauntletState.opponent_deck_problem(path, strict), "",
					"%s is proxy-free, so the gauntlet may deal it" % path)
			else:
				assert_false(DeckList.load_file(path, true).errors.is_empty(),
					"%s holds a proxy, so a strict load refuses it" % path)
			for proxy_name in names:
				proxied[proxy_name] = proxied.get(proxy_name, 0) + 1
		free.sort()
		assert_eq(free, PROXY_FREE[folder], "%s: the proxy-free decks" % folder)
		var expected: Dictionary = PROXIED[folder]
		var missing: Array = []
		for proxy_name in expected:
			if not proxied.has(proxy_name):
				missing.append(proxy_name)
		assert_eq(missing, [], "%s: names the table lists that no deck proxies" % folder)
		var extra: Array = []
		for proxy_name in proxied:
			if not expected.has(proxy_name):
				extra.append(proxy_name)
		assert_eq(extra, [], "%s: names proxied that the table does not list" % folder)
		for proxy_name in expected:
			assert_eq(proxied.get(proxy_name, 0), expected[proxy_name],
				"%s: decks that proxy %s" % [folder, proxy_name])


# ======================================================= defaults unmoved ==

func test_the_five_starters_still_come_first_and_untouched() -> void:
	# Everything that pins `all_deck_paths()[0]` — the Deck Builder tests,
	# the gauntlet's — still gets Big Green, because the store lists the
	# top folder before it walks under it.
	var all := DeckStore.all_deck_paths()
	assert_eq(all[0], "res://decks/big_green.deck")
	var top := DeckStore.deck_paths_in(DeckStore.SHIPPED_DIR)
	assert_eq(top.size(), 5, "the five starter decks, and only those, on top")
	for i in top.size():
		assert_eq(all[i], top[i])
		assert_eq(DeckGroups.of(top[i]), DeckGroups.STARTER, top[i])
	for path in DeckStore.shipped_subfolder_paths():
		assert_true(all.has(path), "%s is listed" % path)
		assert_false(DeckStore.is_user_deck(path), "and is a shipped deck")


func test_the_pickers_headings_are_every_shipped_group_in_order() -> void:
	var grouped := DeckGroups.grouped(DeckStore.all_deck_paths())
	var headings: Array = grouped.keys()
	var shipped: Array = DeckGroups.ORDER.duplicate()
	shipped.erase(DeckGroups.USER)
	for heading in shipped:
		assert_true(headings.has(heading), heading)
	var last := -1
	for heading in headings:
		var at := DeckGroups.ORDER.find(heading)
		assert_gt(at, last, "%s is in ORDER's order" % heading)
		last = at
	for folder in GROUPS:
		assert_eq((grouped[GROUPS[folder][0]] as Array).size(), GROUPS[folder][1],
			folder)
	for folder in NON_MICROPROSE:
		assert_eq((grouped[NON_MICROPROSE[folder][0]] as Array).size(),
			NON_MICROPROSE[folder][1], folder)


func test_the_gauntlet_deals_every_microprose_deck_and_no_proxied_deck() -> void:
	# [QoL] The default roster is the strict-loadable subset: dealt blind,
	# always-proxy decks in a pool of a few hundred ended most twenty-
	# round runs on a deck nobody chose. The proxy-free non-MicroProse
	# decks ARE dealt — a 1994 Worlds list, the Shandalar community's
	# re-tuned enemies — because a strict load takes them whole.
	var roster := GauntletScreen.default_roster()
	assert_eq(roster.size(), 5 + MICROPROSE_TOTAL + _proxy_free_total())
	for folder in GROUPS:
		for path in _paths(folder):
			assert_true(roster.has(path), path)
	for folder in NON_MICROPROSE:
		for path in _group_paths(folder):
			assert_eq(roster.has(path), PROXY_FREE[folder].has(path.get_file()), path)


func test_the_deck_lab_reaches_a_group_only_when_asked_for_it() -> void:
	# DEFAULTS NEVER MOVE: `decks/` without `--group` is still the five
	# starter decks. With `--group` the DIR is walked into its subfolders,
	# and a DIR deck that holds proxies is skipped rather than failing the
	# whole pool — so a non-MicroProse group honestly yields only its
	# proxy-free decks.
	var lab: Object = autofree(load("res://tools/simulate.gd").new())
	assert_eq(lab._expand_pool("decks/", "").size(), 5, "the default field")
	lab._group_filter = DeckGroups.ORIGINALS
	assert_eq(lab._expand_pool("decks/", "").size(), 55)
	lab._group_filter = DeckGroups.KEVIN_BANE
	assert_eq(lab._expand_pool("decks/", "").size(), 8)
	for folder in NON_MICROPROSE:
		lab._group_filter = NON_MICROPROSE[folder][0]
		assert_eq(lab._expand_pool("decks/", "").size(),
			(PROXY_FREE[folder] as Array).size(),
			"%s: the proxied ones skipped with a note, not dealt and not fatal" % folder)
	lab._group_filter = ""
	assert_eq(lab._expand_pool("decks/1997/ancients/", "").size(), 55,
		"a group's own folder needs no flag")
