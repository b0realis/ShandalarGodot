extends GutTest
## THE MIRAGE BLOCK IN THE HELP SCREEN (Pack 8): the glossary explains
## phasing, flanking, flash and the Mirage flash rider, the cleanup
## response window, cumulative upkeep's non-mana payments, the new kinds of
## cost, Heat Wave's life tax — and, page of its own, every Pack 8 digital
## adaptation recorded in the simplified-card ledger and the roadmap, in
## plain words. The glossary stays the final Help chapter and renders with
## every pack disabled (tests/ui/test_help_screen.gd pins both for the
## whole chapter).

const GLOSSARY := preload("res://game/help/ability_glossary.gd")


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


func test_the_three_mirage_pages_come_just_before_the_tempest_pages() -> void:
	var titles := HelpPages.pages().map(func(p: Dictionary) -> String: return String(p.title))
	var at := titles.find("Abilities — Mirage block phasing and flanking")
	assert_gt(at, 0, "the Mirage pages are in the final chapter")
	assert_eq(titles.slice(at, at + 4), ["Abilities — Mirage block phasing and flanking",
		"Abilities — Mirage block flash and costs",
		"Abilities — Mirage block digital adaptations",
		"Abilities — Tempest block shadow and blocking"], "Pack 8's pages, then Pack 9's")


func test_the_mechanics_are_explained() -> void:
	var phasing := _page("Abilities — Mirage block phasing and flanking")
	var flash := _page("Abilities — Mirage block flash and costs")
	assert_eq(_headings(phasing), ["Phasing", "What phasing does not change",
		"Phased-out cards on the table", "Flanking"])
	assert_eq(_headings(flash), ["Flash", "The cleanup response window",
		"Cumulative upkeep paid in other ways", "Alternative costs and paying with objects",
		"Blocking for life"])
	var p := _text(phasing)
	for phrase in ["treated as though it does not exist", "Auras on it phase out and back in",
			"no enters or leaves abilities trigger", "faded and lettered Phased out",
			"Oubliette", "Can't phase out", "the blocker gets -1/-1 until end of turn",
			"Each instance triggers separately"]:
		assert_string_contains(p, phrase)
	var f := _text(flash)
	for phrase in ["any time you could cast an instant",
			"as though they had flash", "sacrificed at the beginning of the next cleanup step",
			"Winding Canyons", "Bounty of the Hunt", "another cleanup step follows",
			"Psychic Vortex", "Aboroth", "Heart of Bogardan",
			"Fireblast", "Spinning Darkness", "costs no mana", "may still cancel",
			"Heat Wave", "1 life for each blocking creature"]:
		assert_string_contains(f, phrase)


func test_every_pack_8_ledger_adaptation_has_a_plain_words_entry() -> void:
	var page := _page("Abilities — Mirage block digital adaptations")
	assert_false(page.is_empty())
	var text := _text(page)
	# docs/simplified-cards.md (Pack 8 rows) and docs/ROADMAP.md (the three
	# engine-wide Pack 8 rows), each by the card a player meets.
	for phrase in ["Debt of Loyalty", "Matopi Golem", "uses the plain shield first",
			"Mind Bend", "Magical Hack", "Sleight of Mind",
			"Shadowbane", "Honorable Passage", "separately for each creature or player",
			"phase out at the same moment", "Gravebane Zombie", "Forbidden Crypt"]:
		assert_string_contains(text, phrase)
	# Warping Wurm's row was lifted (the untap step's triggers join the
	# upkeep's batch in its controller's order, CR 503.1a): no entry.
	assert_false(text.contains("Warping Wurm"), "a lifted row leaves the page")


func test_the_pages_hold_no_development_notes() -> void:
	for title in ["Abilities — Mirage block phasing and flanking",
			"Abilities — Mirage block flash and costs",
			"Abilities — Mirage block digital adaptations"]:
		var text := _text(_page(title)).to_lower()
		for forbidden in ["simplified", "cr 7", "docs/", "engine", "[qol]", "interrupt"]:
			assert_false(text.contains(forbidden), "%s: %s" % [title, forbidden])
