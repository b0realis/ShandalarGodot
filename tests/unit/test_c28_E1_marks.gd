extends GutTest
## THE STRONG PACK CARDS AND THE CAMPAIGN'S PRINTING (0.60.14, the owner's
## pack rulings of 2026-11-03): the one list of strong pack cards
## ([constant CardValue.STRONG_PACK_CARDS]) covers the adventure's ban lists
## and the owner's names; a Fifth Edition card at its Fifth Edition rarity
## is counted so wherever a campaign reads a card's rarity.

var _packs: Array[String] = []


func before_each() -> void:
	_packs = Settings.enabled_card_packs().duplicate()


func after_each() -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in _packs):
			CardPacks.set_enabled(id, id in _packs)
	AdventureSetup.forget()
	CardValue.forget()
	CardTrade.forget()
	AdventurePacks.forget()


## Every identity a numbered pack introduced (its own scripts), Packs 2–10.
func _identities() -> Dictionary:
	var out := {}
	for card in FallenEmpiresPack.names(): out[card] = FallenEmpiresPack.ID
	for card in IceAgePack.new_names(): out[card] = IceAgePack.ID
	for card in HomelandsPack.new_names(): out[card] = HomelandsPack.ID
	for card in AlliancesPack.new_names(): out[card] = AlliancesPack.ID
	for card in PortalPack.new_names(): out[card] = PortalPack.ID
	for card in MirageBlockPack.new_names(): out[card] = MirageBlockPack.ID
	for card in TempestBlockPack.new_names(): out[card] = TempestBlockPack.ID
	for card in UrzaBlockPack.new_names(): out[card] = UrzaBlockPack.ID
	return out


func test_the_strong_list_covers_the_ban_lists_and_the_owner_s_names() -> void:
	var own := _identities()
	for card in ["Necropotence", "Force of Will", "Lion's Eye Diamond", "Mystical Tutor", "Vampiric Tutor",
			"Mox Diamond", "Survival of the Fittest", "Wasteland", "Lotus Petal", "Hymn to Tourach",
			"Ancient Tomb", "City of Traitors"]:
		assert_has(CardValue.STRONG_PACK_CARDS, card)
	# The Urza block's, the owner's pick of 2026-11-06.
	for card in ["Tolarian Academy", "Yawgmoth's Will", "Yawgmoth's Bargain", "Tinker", "Windfall",
			"Memory Jar", "Time Spiral", "Gaea's Cradle", "Serra's Sanctum", "Voltaic Key", "Fluctuator",
			"Grim Monolith", "Frantic Search"]:
		assert_has(CardValue.STRONG_PACK_CARDS, card)
	for card in own:
		if String(card).ends_with(" Tutor"):
			assert_has(CardValue.STRONG_PACK_CARDS, card, "every pack Tutor")
	for key in ClassicBans.LISTS:
		for card in ClassicBans.banned(key) + ClassicBans.restricted(key):
			if own.has(card) and not card in ["Amulet of Quoz", "Timmerian Fiends"]:
				assert_has(CardValue.STRONG_PACK_CARDS, card, "%s is on the %s list" % [card, key])
	for card in CardValue.STRONG_PACK_CARDS:
		assert_true(own.has(card), card + " is a pack's own card: the base keeps 1997's marks")


func test_a_fifth_edition_printing_is_counted_so_in_spoils_and_lair_hoards() -> void:
	for id in ["pack-3", "pack-4", "pack-7"]:
		CardPacks.set_enabled(id, true)
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.packs = ["pack-7"] as Array[String]
	var record := setup.resolve({"pack-7": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(DuelSpoils._rarity("Sengir Autocrat", player), 3, "Fifth Edition's rare")
	assert_eq(LairDuels.rarity_of("Sengir Autocrat", player), 3)
	assert_eq(DuelSpoils._rarity("Sengir Autocrat"), 2, "Homelands' uncommon outside the campaign")
