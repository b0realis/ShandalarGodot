extends GutTest
## THE TEMPEST BLOCK IN THE HELP SCREEN (Pack 9): the glossary explains
## shadow and the creatures that block shadow without having it, the
## block requirements (Watchdog, Provoke, Invasion Plans, Magnetic Web),
## buyback and Memory Crystal, Dream Halls' and Aluren's free casting,
## Rootwater Shaman's flash, licids and their end cost, Volrath's Curse,
## Slivers, Spikes, Humility as printed and the block's other rules-heavy
## cards — and, page of its own, every Pack 9 digital adaptation recorded
## in the simplified-card ledger and the roadmap, in plain words. The
## Dueling Table page says where the licid and Curse payments are, the
## ability-badge icon page explains the small card's painted shadow disc,
## and the Deck Builder page's Pack 9 entry points at the Abilities pages. The
## glossary stays the final Help chapter and renders with every pack
## disabled (tests/ui/test_help_screen.gd pins both for the whole chapter).

const GLOSSARY := preload("res://game/help/ability_glossary.gd")

const TEMPEST_PAGES := [
	"Abilities — Tempest block shadow and blocking",
	"Abilities — Tempest block buyback and casting",
	"Abilities — Tempest block licids, Slivers and Spikes",
	"Abilities — Tempest block notable cards",
	"Abilities — Tempest block digital adaptations",
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


func test_the_tempest_pages_close_the_help_right_after_the_mirage_pages() -> void:
	var titles := HelpPages.pages().map(func(p: Dictionary) -> String: return String(p.title))
	assert_eq(titles.slice(-TEMPEST_PAGES.size()), TEMPEST_PAGES,
		"the newest pack's pages end the final chapter")
	assert_eq(String(titles[titles.size() - TEMPEST_PAGES.size() - 1]),
		"Abilities — Mirage block digital adaptations", "Pack 8's pages come just before")


func test_shadow_and_the_block_requirements_are_explained() -> void:
	var page := _page(TEMPEST_PAGES[0])
	assert_eq(_headings(page), ["Shadow", "Blocking creatures with shadow",
		"Creatures that must block", "Magnetic Web"])
	var text := _text(page)
	for phrase in ["can block or be blocked only by creatures with shadow",
			"cannot block ordinary attackers", "shadow and also flying or reach",
			"does not undo a block", "Shadow Rift", "Dauthi Embrace", "Reality Anchor",
			"Heartwood Dryad", "Wall of Diffusion", "as though they had shadow",
			"They do not have shadow", "Shadowstorm",
			"Watchdog", "Provoke", "Invasion Plans", "attacking player choose all the blocks",
			"without any extra cost", "Nobody is ever forced to pay to block",
			"magnet counter", "attack with all of your able magnetized creatures or with none",
			"block that attacker this turn if able"]:
		assert_string_contains(text, phrase)


func test_buyback_and_the_new_ways_to_cast_are_explained() -> void:
	var page := _page(TEMPEST_PAGES[1])
	assert_eq(_headings(page), ["Buyback", "Memory Crystal",
		"Casting without paying the mana cost", "Casting as though it had flash", "Mox Diamond"])
	var text := _text(page)
	for phrase in ["returns to your hand instead of your graveyard",
			"If it is countered", "goes to the graveyard and the buyback is wasted",
			"Constant Mists", "Forbid", "Slaughter", "Flowstone Flood", "Fanning the Flames",
			"never changes the card's mana value", "a copy of the spell never returns",
			"every player's buyback costs two generic mana cheaper", "never a colored mana symbol",
			"Two Crystals take off four",
			"Dream Halls", "shares a color", "colorless spell cannot be cast this way",
			"Aluren", "mana value 3 or less", "X counts as zero", "buyback must still be paid",
			"Rootwater Shaman", "Aura spells with enchant creature",
			"only when they are cast for free through Aluren", "nothing cast this way is sacrificed",
			"discard a land card", "without ever entering", "not playing one"]:
		assert_string_contains(text, phrase)


func test_licids_the_curse_slivers_and_spikes_are_explained() -> void:
	var page := _page(TEMPEST_PAGES[2])
	assert_eq(_headings(page), ["Licids", "Ending a licid's effect", "Volrath's Curse",
		"Slivers", "Spikes"])
	var text := _text(page)
	for phrase in ["becomes an Aura attached to the target creature, yours or an opponent's",
			"Gliding Licid", "Calming Licid", "Dominating Licid",
			"the licid stays a tapped creature", "the licid goes to its owner's graveyard",
			"may pay the end cost printed on it", "does not use the Spell Chain",
			"becomes a creature again where it stands", "it has its licid ability back",
			"Right-click the licid, or your territory",
			"cannot attack or block", "mana abilities included",
			"sacrifice any permanent they control to ignore the Curse until end of turn",
			"Right-click the enchanted creature, or your territory",
			"your Slivers and your opponent's", "end when the Sliver giving them leaves",
			"two Muscle Slivers give every Sliver +2/+2", "Clot Sliver", "affects only that Sliver",
			"Sliver Queen",
			"A Spike is a 0/0 that enters with +1/+1 counters", "an opponent's, or the Spike itself",
			"before anyone can respond", "dies at once, but the counter it paid for still arrives",
			"remove each other", "both stay and add up"]:
		assert_string_contains(text, phrase)


func test_humility_and_the_blocks_rules_heavy_cards_are_explained() -> void:
	var page := _page(TEMPEST_PAGES[3])
	assert_eq(_headings(page), ["Humility", "Volrath's Shapeshifter",
		"Can't be countered, and Ertai's Meddling", "Static Orb", "The Oaths", "Pandemonium"])
	var text := _text(page)
	for phrase in ["every creature a 1/1 that has lost all its abilities",
			"effects apply in the order they began", "after Humility arrived",
			"still works, while one given earlier is removed",
			"own printed abilities stay off", "a creature with a +1/+1 counter is 2/2",
			"Mishra's Factory animated after Humility is a 2/2",
			"top card of your graveyard is a creature card", "full text",
			"discard a card", "no enters ability triggers",
			"Scragnoth can't be countered", "Power Sink",
			"Ertai's Meddling does not counter", "X delay counters", "X can't be 0",
			"one counter comes off", "It is not cast again",
			"works on a spell that can't be countered",
			"no player untaps more than two permanents", "Winter Orb", "While the Orb itself is tapped",
			"Oath of Druids", "Oath of Ghouls", "Oath of Lieges", "Oath of Mages", "Oath of Scholars",
			"every player's upkeep", "no longer qualifies",
			"either player's, tokens included", "The entering creature's controller, not Pandemonium's",
			"its last power"]:
		assert_string_contains(text, phrase)


func test_every_pack_9_ledger_adaptation_has_a_plain_words_entry() -> void:
	var page := _page(TEMPEST_PAGES[4])
	assert_eq(_headings(page), ["Living Death", "Skeleton Scavengers",
		"Licids and the order of effects", "Whim of Volrath"])
	var text := _text(page)
	# docs/simplified-cards.md (the Pack 9 rows: Living Death; Skeleton
	# Scavengers in the Debt of Loyalty / Matopi Golem row; Whim of Volrath
	# in the Text changes group) and docs/ROADMAP.md (become_licid_aura:
	# a licid keeps its entry timestamp), each by the card a player meets.
	for phrase in ["one after another, the active player's first", "Soul Warden",
			"notices only the creatures returned after it",
			"uses its own shield first without asking", "always gets its +1/+1 counter",
			"Debt of Loyalty and Matopi Golem work the other way round",
			"keeps its place in the order of effects from when it entered the battlefield",
			"Radjan Spirit", "Gliding Licid", "does not give flying back",
			"Humility never meets this case",
			"works like Mind Bend, but only until end of turn", "chosen from a short list",
			"cannot rewrite other rules text"]:
		assert_string_contains(text, phrase)


func test_the_table_page_says_where_the_licid_and_curse_payments_are() -> void:
	var text := _text(_help_page("The Dueling Table"))
	for phrase in ["a licid's cost to end its effect", "the permanent sacrificed to ignore Volrath's Curse",
			"Right-click your territory, or the card concerned"]:
		assert_string_contains(text, phrase)
	# The Mirage bug pass's payments stay named (test_mirage_bugpass_ui.gd).
	for phrase in ["Channel", "Guardian Angel", "Sabertooth Cobra"]:
		assert_string_contains(text, phrase)


func test_the_pack_entry_points_at_the_abilities_pages() -> void:
	var text := HelpPages.all_text()
	assert_string_contains(text, "Pack 9 · The Tempest Block brings Tempest, Stronghold and Exodus")
	assert_string_contains(text, "The Abilities pages at the end of this Help explain shadow, buyback, licids, Slivers, Spikes")


func test_the_shadow_badge_is_explained_with_the_small_cards_own_picture() -> void:
	# The 1997 sheet has no shadow cell (MiniCard.SHADOW_BADGE_KEY): the
	# small card paints its own disc, and the icon page fetches it through
	# the same accessor, so the two cannot drift apart.
	var found: Array = []
	for entry in HelpPages.icon_entries():
		var spec: Dictionary = entry.get("icon", {})
		if String(spec.get("src", "")) == HelpPages.SRC_SHADOW:
			found.append(entry)
	assert_eq(found.size(), 1, "one shadow badge entry")
	if found.is_empty():
		return
	var entry: Dictionary = found[0]
	assert_string_contains(String(entry.name), "Shadow")
	assert_string_contains(String(entry.text), "block or be blocked only by creatures with shadow")
	assert_ne(String(entry.alt), "", "a no-skin stand-in")
	var texture := HelpPages.icon_texture(entry.icon)
	assert_not_null(texture, "drawn without the imported skin")
	assert_eq(texture, MiniCard.shadow_badge(), "the very texture the small card draws")
	var page := _help_page("Icons — abilities on a card in play")
	var on_page := false
	for block in page.get("blocks", []):
		if String(block.get("kind", "")) == HelpPages.ICONS and block.entries.has(entry):
			on_page = true
	assert_true(on_page, "beside the other ability badges")


func test_the_pages_hold_no_development_notes() -> void:
	for title in TEMPEST_PAGES:
		var text := _text(_page(title)).to_lower()
		assert_ne(text, "", title)
		for forbidden in ["simplified", "cr 1", "cr 6", "cr 7", "docs/", "engine", "[qol]",
				"interrupt", "timestamp", "layer 4", "layer 6", "layer 7", "apnap", "special action", "colour"]:
			assert_false(text.contains(forbidden), "%s: %s" % [title, forbidden])
