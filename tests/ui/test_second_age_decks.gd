extends GutTest
## Historical list counts, known cards and saved artwork preferences.
const EXPECTED := {
	"goblin_fire": {"Goblin Cavaliers":2,"Goblin Firestarter":2,"Goblin General":1,"Goblin Glider":2,"Goblin Matron":2,"Goblin Piker":2,"Goblin Raider":2,"Raging Goblin":3,"Blaze":2,"Goblin War Strike":2,"Relentless Assault":1,"Volcanic Hammer":3,"Wildfire":1,"Mountain":15},
	"martial_law": {"Alaborn Cavalier":2,"Alaborn Grenadier":2,"Alaborn Trooper":3,"Alaborn Veteran":1,"Angel of Fury":1,"Armored Griffin":2,"Temple Acolyte":2,"Volunteer Militia":2,"Wild Griffin":3,"Armageddon":1,"Path of Peace":2,"Righteous Charge":2,"Vengeance":2,"Plains":15},
	"natures_assault": {"Bear Cub":3,"Golden Bear":2,"Ironhoof Ox":2,"Norwood Archers":2,"Norwood Ranger":3,"Norwood Riders":2,"River Bear":2,"Sylvan Basilisk":1,"Wild Ox":2,"Alluring Scent":1,"Hurricane":1,"Monstrous Growth":2,"Natural Spring":2,"Forest":15},
	"spellweaver": {"Air Elemental":2,"Apprentice Sorcerer":2,"Talas Air Ship":2,"Talas Explorer":2,"Talas Merchant":3,"Talas Researcher":1,"Talas Scout":3,"Talas Warrior":1,"False Summoning":2,"Mystic Denial":2,"Exhaustion":1,"Time Ebb":2,"Touch of Brilliance":2,"Island":15},
	"the_nightstalkers": {"Abyssal Nightstalker":2,"Brutal Nightstalker":2,"Dakmor Bat":2,"Lurking Nightstalker":3,"Nightstalker Engine":1,"Predatory Nightstalker":2,"Prowling Nightstalker":3,"Raiding Nightstalker":2,"Ancient Craving":1,"Cruel Edict":2,"Hand of Death":2,"Mind Rot":2,"Return of the Nightstalkers":1,"Swamp":15},
	"preconstructed_deck_1": {"Dakmor Bat":1,"Dakmor Scorpion":1,"Goblin Cavaliers":1,"Goblin Piker":1,"Goblin Raider":1,"Lynx":1,"Moaning Spirit":1,"Norwood Ranger":1,"Obsidian Giant":1,"Ogre Berserker":1,"Plated Wurm":1,"Prowling Nightstalker":1,"Raging Goblin":1,"Coercion":1,"Hand of Death":1,"Mind Rot":1,"Volcanic Hammer":1,"Forest":3,"Mountain":5,"Swamp":5},
	"preconstructed_deck_2": {"Alaborn Trooper":1,"Angel of Mercy":1,"Bear Cub":1,"Golden Bear":1,"Screeching Drake":1,"Talas Air Ship":1,"Talas Explorer":1,"Talas Merchant":1,"Talas Scout":1,"Temple Acolyte":1,"Trokin High Guard":1,"Volunteer Militia":1,"Wild Griffin":1,"Bee Sting":1,"Path of Peace":1,"Theft of Dreams":1,"Time Ebb":1,"Forest":3,"Island":5,"Plains":5},
}

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)

func after_each() -> void:
	CardPacks.set_enabled("pack-6", false)

func test_original_decklists_and_printings() -> void:
	for slug in EXPECTED:
		var deck_path: String = "res://decks/portal_second_age/" + slug + ".deck"
		var deck := DeckList.load_file(deck_path)
		assert_eq(deck.errors, [])
		var counts := {}
		for name in deck.cards: counts[name] = int(counts.get(name, 0)) + 1
		assert_eq(counts, EXPECTED[slug], slug)
		assert_eq(deck.cards.size(), 30 if String(slug).begins_with("preconstructed") else 40)
		assert_eq(deck.required_packs, ["pack-6"])
		assert_eq(DeckGroups.of(deck_path), DeckGroups.SECOND_AGE)
		for name in counts:
			assert_true(CardRegistry.card_in_set(name, "p02"), name)
			assert_eq(deck.printings.get(name), "p02", name)

func test_second_age_help_is_available_without_the_pack() -> void:
	CardPacks.set_enabled("pack-6", false)
	var pages := HelpPages.pages()
	assert_eq(pages.filter(func(page: Dictionary) -> bool: return String(page.title).begins_with("Second Age · ")).size(), 3)
