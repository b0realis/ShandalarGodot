extends GutTest
## THE URZA BLOCK IN THE HELP SCREEN (Pack 10): the glossary explains echo
## and cycling (the cycling lands, Fluctuator), the enchantments that
## become creatures (Opal, Veiled, Hidden, Lurking), Opalescence with
## Humility in both orders and Soul Sculptor, "untap up to N lands" and how
## the lands are chosen, the paid untaps and the counting lands, verse
## counters and the other counters cashed in (Serra's Hymn's divided
## prevention, Archery Training), the cards put onto the battlefield
## together and where their Auras go, playing from the graveyard and the
## library's top (Yawgmoth's Will, Temporal Aperture), the "reveal any
## number" cards and Metalworker, Abundance, Memory Jar, the "put into a
## graveyard from anywhere" cards, Multani's Presence, the Auras that come
## back, the combat cards (Defensive Formation, Okk, Outmaneuver), Storage
## Matrix, Thran Turbine and Contamination, Damping Engine and the block's
## other rules-heavy cards — in plain words,
## each checked against the card scripts and their tests
## (tests/cards/test_pack_10_*.gd). Pack 10 has no digital adaptation of
## its own; Pack 9's Living Death entry now says its creatures return
## together. The Dueling Table page and the duel's small helps say where to
## click to cycle, to play from the graveyard and to play the library's
## top card, and that Damping Engine's sacrifice is made from the territory
## menu; the Showcase's "Help for this card..." finds the new words;
## the Deck Builder page's Pack 10 entry points at the Abilities pages.
## The glossary stays the final Help chapter and renders with every pack
## disabled (tests/ui/test_help_screen.gd pins both for the whole chapter;
## the last test here renders the Urza pages themselves that way).

const GLOSSARY := preload("res://game/help/ability_glossary.gd")

const URZA_PAGES := [
	"Abilities — Urza block echo and cycling",
	"Abilities — Urza block enchantments that become creatures",
	"Abilities — Urza block untapping and mana",
	"Abilities — Urza block counters to cash in",
	"Abilities — Urza block cards put onto the battlefield",
	"Abilities — Urza block other zones and revealed cards",
	"Abilities — Urza block graveyards and counterspells",
	"Abilities — Urza block combat",
	"Abilities — Urza block notable cards",
]


func _page(title: String) -> Dictionary:
	for page in GLOSSARY.pages():
		if String(page.title) == title:
			return page
	return {}


func _text(page: Dictionary) -> String:
	var out := PackedStringArray()
	for block in page.get("blocks", []):
		out.append(String(block.get("text", "")))
	return "\n".join(out)


func _headings(page: Dictionary) -> Array:
	var out: Array = []
	for block in page.get("blocks", []):
		if String(block.get("kind", "")) == "heading":
			out.append(String(block.text))
	return out


func _help_page(title: String) -> Dictionary:
	for page in HelpPages.pages():
		if String(page.title) == title:
			return page
	return {}


func _says(text: String, phrases: Array) -> void:
	for phrase in phrases:
		assert_string_contains(text, String(phrase))


func test_the_urza_pages_close_the_help_right_after_the_tempest_pages() -> void:
	var titles := HelpPages.pages().map(func(p: Dictionary) -> String: return String(p.title))
	assert_eq(titles.slice(-URZA_PAGES.size()), URZA_PAGES,
		"the newest pack's pages end the final chapter")
	assert_eq(String(titles[titles.size() - URZA_PAGES.size() - 1]),
		"Abilities — Tempest block digital adaptations", "Pack 9's pages come just before")


func test_echo_and_cycling_are_explained() -> void:
	var page := _page(URZA_PAGES[0])
	assert_eq(_headings(page), ["Echo", "Echo after a change", "Cycling", "Cycling lands and Fluctuator"])
	_says(_text(page), ["pay its echo cost or sacrifice it", "You are asked once",
		"If you cannot pay, you are not asked", "regeneration cannot stop",
		"owes echo again", "its old controller owes nothing", "Phasing out and back in does not count",
		"under Humility, has no echo",
		"discard the card to draw a card", "Click the card in your hand, or right-click it, and choose Cycling",
		"any time you could cast an instant", "stays in your graveyard whatever happens to the draw",
		"A card on the battlefield cannot be cycled", "Megrim",
		"Blasted Landscape", "Drifting Meadow", "Polluted Mire", "Remote Isle", "Slippery Karst",
		"Smoldering Crater", "play it as your land for the turn, or cycle it",
		"does not use up your land play", "two generic mana less", "It changes no other cost"])


func test_the_enchantments_that_become_creatures_are_explained() -> void:
	var page := _page(URZA_PAGES[1])
	assert_eq(_headings(page), ["Opal, Veiled and Hidden enchantments", "Lurking Evil", "Opalescence",
		"Opalescence and Humility", "Soul Sculptor"])
	_says(_text(page), ["if the permanent is still an enchantment",
		"stops being an enchantment for the rest of the game", "an Aura that enchants enchantments falls off",
		"Disenchant can no longer target it", "it can attack if you have controlled it since your turn began",
		"Opal Acrolith can become an enchantment again for nothing", "Hidden Stag",
		"Pay half your life, rounded up", "at 7 life you pay 4", "Lurking Jackals", "Lurking Skirge",
		"each other enchantment that is not an Aura", "equal to its mana value",
		"Glorious Anthem is a 3/3, and its own +1/+1 makes it a 4/4",
		"Disenchant and Wrath of God both destroy it", "mana value 0 is a 0/0 and dies",
		"Two Opalescences make each other creatures", "Opalescence leaves it alone",
		"Humility is a creature too, a 4/4", "its effect goes on all the same",
		"Humility first, then Opalescence", "every other creature is a 1/1",
		"Opalescence first, then Humility", "Humility and the enchantments included",
		"Even two Opalescences with Humility kill nothing",
		"until a player casts a creature spell", "before that spell resolves",
		"even if Soul Sculptor leaves the battlefield", "a creature the size of its mana value, still without abilities"])


func test_untapping_lands_and_the_counting_lands_are_explained() -> void:
	var page := _page(URZA_PAGES[2])
	assert_eq(_headings(page), ["Untap up to N lands", "Choosing the lands", "Untapping for a price",
		"Lands that count", "Storage Matrix", "Thran Turbine and Contamination"])
	_says(_text(page), ["Great Whale", "Peregrine Drake", "Palinchron", "Cloud of Faeries", "Treachery",
		"Snap", "Frantic Search", "Rewind", "Time Spiral", "gives that mana back",
		"even if the creature has left the battlefield", "Winter Orb and Static Orb do not limit it",
		"Rewind untaps nothing if the spell it aims at is gone",
		"These cards target nothing", "First choose how many lands", "one at a time",
		"Only tapped lands are offered, yours first", "Tolarian Academy before an Island",
		"A tapped land of your opponent's may be chosen too", "nothing is asked",
		"Grim Monolith", "pay {4}", "8 life to untap the Colossus", "Horseshoe Crab", "Morphling",
		"works even on the turn the creature arrives", "Voltaic Key", "loop limit",
		"for each artifact you control", "Gaea's Cradle", "Serra's Sanctum", "with none, it makes nothing",
		"an animated land is a creature", "no longer for the Sanctum", "Automatic mana payment counts them",
		"a second one of the same name goes to the graveyard",
		"each player chooses artifacts, creatures or lands in their untap step",
		"an artifact land or an artifact creature counts as either of its kinds",
		"unless nothing of yours is tapped", "A tapped Storage Matrix restricts nothing",
		"{C}{C} that cannot be spent to cast spells", "echo, cumulative upkeep", "burns under mana burn",
		"every land tapped for mana makes exactly one black mana", "Gaea's Cradle and Tolarian Academy make one black mana too",
		"Mana Flare still adds", "sacrifice a creature, or it is sacrificed itself"])


func test_verse_and_the_other_counters_are_explained() -> void:
	var page := _page(URZA_PAGES[3])
	assert_eq(_headings(page), ["Verse counters", "Serra's Hymn", "Counters that pay out", "Archery Training"])
	_says(_text(page), ["Serra's Liturgy", "Lilting Refrain", "Recantation", "Discordant Dirge",
		"Vile Requiem", "Rumbling Crescendo", "Torch Song", "Midsummer Revel", "War Dance",
		"whether to put a verse counter on them", "up to X targets, X is counted as you choose the targets, before the sacrifice",
		"as it was sacrificed", "a counter added in response changes nothing",
		"divided as you choose among any number of creatures and players",
		"at most one target for each point", "Click a target once for each point",
		"takes its share with it", "With no verse counter there is nothing to prevent",
		"Barrin's Codex", "Lotus Blossom", "Powder Keg", "Smokestack",
		"page, petal, fuse or soot counter", "Momentum", "Private Research", "Incendiary", "Festering Wound",
		"you may put an arrow counter", "target attacking or blocking creature",
		"still deals the number it had", "two separate abilities, each counting its own arrows"])


func test_cards_put_onto_the_battlefield_are_explained() -> void:
	var page := _page(URZA_PAGES[4])
	assert_eq(_headings(page), ["Arriving together", "Show and Tell", "Auras put onto the battlefield",
		"Sneak Attack and other cards put into play"])
	_says(_text(page), ["Show and Tell", "Replenish", "Exhume", "Victimize", "Planar Birth",
		"Defense of the Heart", "Living Death", "Every choice is made first, the active player's before the opponent's",
		"all the cards arrive together", "Soul Warden, sees every one of the others",
		"no counterspell can stop them", "is not your land for the turn",
		"artifact, creature, enchantment or land card", "without seeing that choice",
		"neither card is shown until both players have chosen", "then both are revealed and arrive together",
		"each under its owner's control",
		"targets nothing", "among the permanents already there, never one arriving with it",
		"protection still keeps it off", "Replenish leaves it in your graveyard",
		"offer only an Aura that has something to enchant",
		"any time you could cast an instant", "It gains haste",
		"sacrificed at the beginning of the next end step if you still control it",
		"Copper Gnomes", "Quicksilver Amulet", "Tinker", "Academy Rector",
		"a Phyrexian Processor still asks for its life"])


func test_playing_from_other_zones_and_revealing_are_explained() -> void:
	var page := _page(URZA_PAGES[5])
	assert_eq(_headings(page), ["Yawgmoth's Will", "Temporal Aperture", "Revealing cards from your hand",
		"Abundance", "Memory Jar"])
	_says(_text(page), ["play lands and cast spells from your graveyard",
		"A land played from there is your land for the turn", "keeps its usual timing and costs",
		"is exiled instead: Yawgmoth's Will itself", "click your graveyard: the cards you may play now are ringed",
		"its top card is revealed to both players", "as long as that card stays on top",
		"without paying its mana cost", "with X counting as zero",
		"Drawing it, putting another card on top or any shuffle of your library ends the offer for good",
		"Click your library to play the card",
		"The Seers and the Scents", "Rofellos's Gift", "choose how many, then which ones",
		"The revealed cards stay in your hand, both players see them", "Revealing none is allowed",
		"Metalworker does the same as it taps for mana: {C}{C} for each artifact card revealed",
		"then which ones unless you reveal them all", "counts every artifact card in your hand",
		"draw the card, or reveal cards from the top of your library until a land, or until a nonland card",
		"in the order you choose", "you draw nothing", "The duel stops in your draw step to ask you",
		"face down, where nobody may look at them", "draws seven cards",
		"discards their hand and takes back the cards exiled this way", "the next turn's end step"])


func test_graveyard_and_counterspell_triggers_are_explained() -> void:
	var page := _page(URZA_PAGES[6])
	assert_eq(_headings(page), ["Put into a graveyard from anywhere", "Serra Avatar", "Multani's Presence",
		"Auras that come back"])
	_says(_text(page), ["whatever it came from", "Planar Void exiles each other card put into any graveyard",
		"Energy Field prevents all damage dealt to you by sources you don't control",
		"even your own spell as it resolves", "Compost", "Tokens are not cards",
		"a card exiled instead, by Yawgmoth's Will or Forbidden Crypt, never reached a graveyard",
		"equal to your life total", "it dies at once", "shuffled back into its owner's library",
		"your hand, your library or the Spell Chain",
		"Whenever a spell you cast is countered", "Force Spike", "was not countered",
		"a copy of a spell was never cast",
		"Rancor", "Brilliant Halo", "Launch", "Despondency", "Fiery Mantle", "Fortitude", "Spreading Algae",
		"Cessation", "Slow Motion", "Sleeper's Guile", "Sluggishness",
		"return to their owner's hand when they are put into a graveyard from the battlefield",
		"An Aura exiled instead"])


func test_the_combat_cards_are_explained() -> void:
	var page := _page(URZA_PAGES[7])
	assert_eq(_headings(page), ["Defensive Formation", "Okk", "Outmaneuver",
		"Blocking many, and needing many blockers"])
	_says(_text(page), ["rather than the attacking player, assign the combat damage of each creature attacking them",
		"may keep it all on the blockers", "the attacking player's own Defensive Formation does nothing",
		"only if a creature with greater power attacks too", "a later boost changes nothing",
		"Under Humility it has no abilities and so no restriction",
		"cast it after blockers are declared", "as though it were not blocked", "It still counts as blocked",
		"Thorn Elemental", "Wall of Glare can block any number of creatures", "Phyrexian Colossus",
		"three or more creatures"])


func test_the_blocks_notable_cards_are_explained() -> void:
	var page := _page(URZA_PAGES[8])
	assert_eq(_headings(page), ["Gilded Drake", "Donate and Treachery", "Masticore",
		"Phyrexian Processor", "Thran Weaponry", "Defense Grid and Thran Lens", "Damping Engine"])
	_says(_text(page), ["change controllers for good", "the Drake is sacrificed instead",
		"If the Drake is no longer yours by then, nothing happens",
		"Donate gives target player control of target permanent you control", "untaps up to five lands",
		"discard a card or sacrifice Masticore", "Megrim, still sees it",
		"choose how much life to pay", "X being the life paid", "the Minion still comes at full size",
		"Paying no life makes 0/0 Minions",
		"A creature that arrives later gets nothing", "The bonus ends for good",
		"{3} more except during its controller's own turn", "Abilities are not spells",
		"every permanent colorless", "Terror can destroy it", "a tapped Grid or Lens does nothing",
		"the player who controls more permanents than the other", "artifact, creature and enchantment spells",
		"with equal counts it stops nobody", "Damping Engine itself if it is theirs", "to ignore it until end of turn",
		"right-click your territory, or Damping Engine", "a tapped Damping Engine does nothing"])


func test_living_death_returns_its_creatures_together() -> void:
	# Pack 9's ledger row is gone (MtgGame.put_onto_battlefield_together);
	# the entry stays on the Tempest adaptations page with the new words.
	var page := _page("Abilities — Tempest block digital adaptations")
	assert_true(_headings(page).has("Living Death"))
	var text := _text(page)
	assert_string_contains(text, "Living Death returns every exiled creature at the same moment, "
		+ "both players' together, so a returned Soul Warden sees all the others arrive.")
	assert_false(text.contains("one after another"), "the old adaptation is not taught")


func test_the_table_page_says_where_to_click() -> void:
	var text := _text(_help_page("The Dueling Table"))
	_says(text, ["such as cycling, asks what you want when you click it", "Cycling {2}",
		"its right-click menu offers the ability too",
		"as Yawgmoth's Will allows, click your graveyard", "the cards you may play now are ringed",
		"as Temporal Aperture allows, a click on your library shows that card and plays it",
		"offers to be cast without paying its mana cost",
		"the permanent sacrificed to ignore Volrath's Curse or Damping Engine"])
	# The duel's small helps say the same, menu by menu.
	_says(String(HelpPages.mini(HelpPages.MINI_HAND)["text"]), ["whether to cast it or to cycle it"])
	_says(String(HelpPages.mini(HelpPages.MINI_LIBRARY)["text"]), ["Temporal Aperture", "click the pile to play it"])
	_says(String(HelpPages.mini(HelpPages.MINI_GRAVEYARD)["text"]), ["Yawgmoth's Will", "ringed: click one to play it"])


func test_help_for_this_card_finds_the_new_words() -> void:
	var herald := String(HelpPages.mini_card("Herald of Serra",
		"Flying, vigilance\nEcho {2}{W}{W} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)")["text"])
	assert_string_contains(herald, "Echo — ")
	var isle := String(HelpPages.mini_card("Remote Isle",
		"This land enters tapped.\n{T}: Add {U}.\nCycling {2} ({2}, Discard this card: Draw a card.)")["text"])
	assert_string_contains(isle, "Cycling lands and Fluctuator — ", "the entry naming the card")
	assert_string_contains(isle, "Cycling — ", "and the word")
	var song := String(HelpPages.mini_card("Torch Song",
		"At the beginning of your upkeep, you may put a verse counter on this enchantment.")["text"])
	assert_string_contains(song, "Verse counters — ")
	var whale := String(HelpPages.mini_card("Great Whale",
		"When this creature enters, untap up to seven lands.")["text"])
	assert_string_contains(whale, "Untap up to N lands — ")
	var seer := String(HelpPages.mini_card("Ivy Seer",
		"{2}{G}, {T}: Reveal any number of green cards in your hand. Target creature gets +X/+X until end of turn, where X is the number of cards revealed this way.")["text"])
	assert_string_contains(seer, "Revealing cards from your hand — ")
	var void_ := String(HelpPages.mini_card("Planar Void",
		"Whenever another card is put into a graveyard from anywhere, exile that card.")["text"])
	assert_string_contains(void_, "Put into a graveyard from anywhere — ")
	assert_eq(HelpPages.mini_card("Opalescence", "")["page"], URZA_PAGES[1], "the card's own page first")


func test_the_pack_entry_points_at_the_abilities_pages() -> void:
	var text := HelpPages.all_text()
	assert_string_contains(text, "Pack 10: The Urza Block brings Urza's Saga, Urza's Legacy and Urza's Destiny")
	assert_string_contains(text, "The Abilities pages at the end of this Help explain echo, cycling, "
		+ "the enchantments that become creatures, untapping lands, verse counters")


func test_the_counter_page_names_the_urza_counters() -> void:
	# The new kinds have no 1997 stone: they wear the dark chip, and the
	# page says so rather than inventing a picture.
	var text := HelpPages.all_text()
	assert_string_contains(text, "the Urza block's verse, page, petal, fuse, soot, arrow, growth "
		+ "and infection counters")
	for kind in ["verse", "page", "petal", "fuse", "soot", "arrow", "growth", "infection"]:
		assert_eq(CounterMarks.tile_for("Serra's Liturgy", kind), -1, "%s really has no stone" % kind)


func test_the_pages_hold_no_development_notes() -> void:
	for title in URZA_PAGES:
		# Card names are not notes: "Damping Engine" is a card.
		var text := _text(_page(title)).to_lower().replace("damping engine", "")
		assert_ne(text, "", title)
		for forbidden in ["simplified", "cr 1", "cr 6", "cr 7", "docs/", "engine", "[qol]",
				"interrupt", "timestamp", "layer 4", "layer 6", "layer 7", "apnap", "special action",
				"colour", "pack 10", "test"]:
			assert_false(text.contains(forbidden), "%s: %s" % [title, forbidden])


func test_the_urza_pages_render_with_every_pack_disabled() -> void:
	var screen: HelpScreen = load("res://game/help/help_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var before := Settings.enabled_card_packs()
	Settings.set_value("enabled_card_packs", [], false)
	CardPacks._configure_registry()
	var titles := HelpPages.pages().map(func(p: Dictionary) -> String: return String(p.title))
	for title in URZA_PAGES:
		screen.go_to(titles.find(title))
		await get_tree().process_frame
		var labels: Array = []
		for node in screen.find_children("*", "Label", true, false):
			if (node as Label).text != "":
				labels.append((node as Label).text)
		assert_true(labels.has(title), "%s shows its title" % title)
		assert_gt(labels.size(), 8, "%s draws its entries" % title)
	Settings.set_value("enabled_card_packs", before, false)
	CardPacks._configure_registry()
