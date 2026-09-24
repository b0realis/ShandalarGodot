extends SceneTree
## Deterministic complete Wizard-v-Wizard Portal duels in both rulesets.
## Run under the repository's isolated shandalar_test profile, never the
## player's profile. The pack must already be locally built and installed.

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--version") or args.has("-V"):
		print("pack_6_duel_audit.gd ", ProjectSettings.get_setting("application/config/version", "unknown"))
		quit(0)
		return
	if args.has("--help") or args.has("-h"):
		print("Pack 6 Portal audit — complete Wizard duels and actual card-use counts in both rulesets.")
		print("--rounds N (default 1, max 1000); --seed N (default 67000). Five themed decks, 10 duels per round.")
		print("--only-index N replays that matchup in both rulesets for debugging (zero based).")
		print("Use tools/runtime.sh: shandalar_find_godot; shandalar_find_timeout; shandalar_test_profile.")
		print("Set SHANDALAR_PACK_6 to your locally built Pack-6-Portal.zip; run with --script res://tools/pack_6_duel_audit.gd.")
		quit(0)
		return
	var rounds := 1
	var base_seed := 67000
	var only_index := -1
	var at := 0
	while at < args.size():
		if args[at] not in ["--rounds", "--seed", "--only-index"] or at + 1 >= args.size() or not args[at + 1].is_valid_int():
			printerr("Invalid audit arguments; use --help")
			quit(3)
			return
		if args[at] == "--rounds": rounds = int(args[at + 1])
		elif args[at] == "--seed": base_seed = int(args[at + 1])
		else: only_index = int(args[at + 1])
		at += 2
	if rounds < 1 or rounds > 1000 or base_seed < 0:
		printerr("Rounds must be 1..1000 and seed nonnegative")
		quit(3)
		return
	if not OS.has_feature("shandalar_test"):
		printerr("PACK 6 AI AUDIT: requires GODOT_EDITOR_CUSTOM_FEATURES=shandalar_test")
		quit(2)
		return
	Settings.set_value("enabled_card_packs", ["pack-6"], false)
	root.get_node("CardPacks")._configure_registry()
	CardRegistry.ensure_loaded()
	if CardRegistry.size() != 1076:
		printerr("PACK 6 AI AUDIT: install the real local Pack-6-Portal.zip first")
		quit(2)
		return
	var specs := [
		[
			"Forest",
			[
				"Gorilla Warrior",
				"Jungle Lion",
				"Plant Elemental",
				"Wood Elves",
				"Bull Hippo",
				"Stalking Tiger",
				"Monstrous Growth",
				"Bee Sting",
				"Nature's Lore"
			]
		],
		[
			"Swamp",
			[
				"Feral Shadow",
				"Serpent Warrior",
				"Gravedigger",
				"Cruel Bargain",
				"Hand of Death",
				"Vampiric Touch",
				"Mind Rot",
				"Undying Beast",
			"Dread Reaper"
			]
		],
		[
			"Mountain",
			[
				"Goblin Bully",
				"Raging Goblin",
				"Hulking Goblin",
				"Hill Giant",
				"Volcanic Hammer",
				"Spitting Earth",
				"Fire Imp",
				"Forked Lightning",
				"Blaze"
			]
		],
		[
			"Plains",
			[
				"Armored Pegasus",
				"Venerable Monk",
				"Charging Paladin",
				"Spiritual Guardian",
				"Seasoned Marshal",
				"Path of Peace",
				"Angelic Blessing",
				"Warrior's Charge",
				"Devoted Hero"
			]
		],
		[
			"Island",
			[
				"Cloud Pirates",
				"Cloud Spirit",
				"Phantom Warrior",
				"Time Ebb",
				"Man-o'-War",
				"Omen",
				"Mystic Denial",
				"Theft of Dreams",
				"Touch of Brilliance"
			]
		]
	]
	var decks: Array = []
	for spec in specs:
		var deck: Array[String] = []
		for _i in 24: deck.append(spec[0])
		for name in spec[1]:
			if not CardRegistry.has_card(name):
				printerr("PACK 6 AI AUDIT: missing " + name)
				quit(2)
				return
			for _i in 4: deck.append(name)
		decks.append(deck)
	var completed := 0
	var use_counts := {}
	for edition in ["modern", "fifth"]:
		for match_index in decks.size() * rounds:
			if only_index >= 0 and match_index != only_index: continue
			var i := match_index % decks.size()
			var round_index := match_index / decks.size()
			var opponent := (i + 1 + round_index % (decks.size() - 1)) % decks.size()
			var game := MtgGame.new()
			var duel_seed := base_seed + match_index + (100000 if edition == "fifth" else 0)
			game.setup(decks[i], decks[opponent], specs[i][0], specs[opponent][0], 20, 20, duel_seed)
			game.rules.set_edition(edition)
			var a := AiPlayer.new(0, AiProfile.wizard())
			var b := AiPlayer.new(1, AiProfile.wizard())
			game.set_agent(0, a)
			game.set_agent(1, b)
			game.start()
			if not AiPlayer.play_out(game, a, b):
				printerr("PACK 6 AI AUDIT FAILED: ", edition, " seed ", duel_seed, " turn ", game.turn_number)
				for player in game.players:
					printerr("STATE ", player.player_name, " life=", player.life, " library=", player.library.size(), " hand=", player.hand.map(func(card): return card.data.card_name))
					printerr("BOARD ", player.battlefield.map(func(card): return "%s %s/%s tapped=%s" % [card.data.card_name, card.cur_power, card.cur_toughness, card.tapped]))
				for line in game.log_lines.slice(-90): printerr(line)
				quit(2)
				return
			completed += 1
			for meta in game.log_meta:
				if meta.kind not in ["cast", "activate"] or String(meta.card).is_empty(): continue
				var key := "%s: %s" % [meta.kind, meta.card]
				use_counts[key] = int(use_counts.get(key, 0)) + 1
			print("PACK 6 AI DUEL OK: ", edition, " seed ", duel_seed, " turns ", game.turn_number, " winner ", game.winner)
	var keys: Array = use_counts.keys()
	keys.sort()
	for key in keys: print("PACK 6 ACTUAL USE: ", key, " = ", use_counts[key])
	print("PACK 6 AI AUDIT OK: ", completed, " completed full duels")
	quit(0)
