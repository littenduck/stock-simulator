## The rules of MusicHost: on the web the music waits for the first click/key press (browsers keep audio suspended until then),
## and asking for the track that is already playing does not restart it.
extends TestCase


func test_only_the_web_waits_and_only_until_the_first_press() -> void:
	assert_true(MusicHost.needs_gesture(true, false), "web, no press yet: wait")
	assert_false(MusicHost.needs_gesture(true, true), "web, a press was already seen: start now")
	assert_false(MusicHost.needs_gesture(false, false), "desktop: start now")
	assert_false(MusicHost.needs_gesture(false, true), "desktop: start now")


func test_presses_count_but_releases_and_motion_do_not() -> void:
	var down := InputEventMouseButton.new()
	down.pressed = true
	var up := InputEventMouseButton.new()
	up.pressed = false
	assert_true(MusicHost.is_user_gesture(down), "mouse button down")
	assert_false(MusicHost.is_user_gesture(up), "mouse button up")
	var key := InputEventKey.new()
	key.pressed = true
	assert_true(MusicHost.is_user_gesture(key), "key down")
	key = InputEventKey.new()
	key.pressed = false
	assert_false(MusicHost.is_user_gesture(key), "key up")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	assert_true(MusicHost.is_user_gesture(touch), "touch down")
	assert_false(MusicHost.is_user_gesture(InputEventMouseMotion.new()), "mouse motion")


func test_the_same_track_keeps_playing_across_screens_but_a_new_one_starts() -> void:
	var menu := "res://audio/music/startmenu.ogg"
	var game := "res://audio/music/gameplay.ogg"
	assert_false(MusicHost.should_restart(menu, menu, true), "run setup asks for the menu theme that is already playing")
	assert_true(MusicHost.should_restart(menu, game, true), "the game screen asks for another track")
	assert_true(MusicHost.should_restart("", menu, false), "nothing has played yet")
	assert_true(MusicHost.should_restart(menu, menu, false), "same track but it is not playing (stopped): start it")
