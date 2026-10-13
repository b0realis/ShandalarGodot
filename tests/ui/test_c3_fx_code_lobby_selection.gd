extends GutTest
## THE GAME BROWSER'S SELECTED HOST (repository check 2026-10-13, d1-33).
##
## A pasted invitation that does not match the host chosen in the Game
## Browser is refused, and the notice said "Clear the selection" — a button
## the lobby does not have. The way to drop the selection is the search
## button, which reads "Stop LAN search" while the browser is searching;
## the notice now names it. And a search the lobby stops by itself (the
## player left the Game Browser) drops the selection too, as the button
## does, so a host that is no longer listed can never refuse an invitation.
## No socket opens in these tests: the discovery is never started.

const PEM := "-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n"

var _had_name := false
var _saved_name: Variant


func before_each() -> void:
	_had_name = Settings.has_value(SgIdentity.KEY)
	_saved_name = Settings.get_value(SgIdentity.KEY, "")
	Settings.clear_value(SgIdentity.KEY)


func after_each() -> void:
	if _had_name: Settings.set_value(SgIdentity.KEY, _saved_name)
	else: Settings.clear_value(SgIdentity.KEY)


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	lobby._nickname.text = "Forest Fox"
	return lobby


## A browser that is searching, without a socket: the discovery is kept
## out of the tree (nothing polls it) and only says it is searching.
func _searching(lobby: SgLobby) -> void:
	lobby._show_page("browser")
	lobby._discovery = SgLanDiscovery.new()
	autofree(lobby._discovery)
	lobby._discovery.scanning = true
	lobby._selected_host = {"address": "192.168.0.5", "port": 17897,
		"fingerprint": "a".repeat(64), "name": "Forest Fox"}
	lobby._refresh()


func test_the_mismatch_notice_names_the_button_that_clears_the_selection() -> void:
	var lobby := _lobby()
	_searching(lobby)
	var other := SgLanInvite.create("192.168.0.9", 17897, "b".repeat(64), PEM)
	assert_false(other.is_empty(), "control: an invitation from another host")
	lobby._code.text = other
	lobby._connect_local()
	assert_false(lobby.client._wanted, "control: refused, no socket")
	assert_string_contains(lobby._notice.text, "does not match the selected host")
	assert_string_contains(lobby._notice.text, "Choose Stop LAN search")
	assert_eq(lobby._scan.text, "Stop LAN search", "the button the notice names is there")
	assert_true(lobby._scan.is_visible_in_tree() and not lobby._scan.disabled, "and can be pressed")
	lobby._scan.pressed.emit()
	assert_true(lobby._selected_host.is_empty(), "and pressing it clears the selection")
	assert_eq(lobby._scan.text, "Find LAN games")


func test_a_search_stopped_by_leaving_the_browser_drops_its_selection() -> void:
	var lobby := _lobby()
	_searching(lobby)
	assert_false(lobby._selected_host.is_empty(), "control: a host is selected")
	lobby._show_page("home")
	assert_false(lobby._discovery.scanning, "control: leaving the browser stops the search")
	assert_true(lobby._selected_host.is_empty(), "and drops the selection with it")
	lobby._show_page("browser")
	assert_eq(lobby._scan.text, "Find LAN games", "control: back in the browser, not searching")
