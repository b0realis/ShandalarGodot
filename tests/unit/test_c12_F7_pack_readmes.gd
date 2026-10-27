extends GutTest
## THE BLOCK PACKS' READMES COUNT AS THEIR MANIFESTS DO (the bug campaign
## c12, fixer F7, after D1's note). Pack 8's README said the game already
## had 43 of its cards and Pack 9's 42 — the reprints less the five basic
## lands — while each manifest counts every distinct card the game already
## had: 669 − 621 = 48 and 621 − 574 = 47.

const PACKS := ["pack_8_mirage_block", "pack_9_tempest_block"]


func test_each_readme_counts_the_cards_the_game_already_has_as_its_manifest() -> void:
	for pack in PACKS:
		var folder := "res://packaging/card_packs/%s/" % pack
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
		var found := RegEx.create_from_string("(\\d+) distinct cards .* (\\d+) of them new").search(
			String(manifest["description"]))
		assert_not_null(found, "%s: control, the manifest's counts" % pack)
		if found == null:
			continue
		var already := int(found.get_string(1)) - int(found.get_string(2))
		var reprints: Array = JSON.parse_string(FileAccess.get_file_as_string(folder + "reprint_names.json"))
		assert_eq(reprints.size(), already, "%s: the reprint list agrees" % pack)
		var readme := FileAccess.get_file_as_string(folder + "README.txt")
		assert_string_contains(readme, "The %d cards the game already has" % already, pack)
		var shared: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "shared_names.json"))
		assert_string_contains(readme.replace("\n", " "), "the other %d" % shared.size(), pack)
