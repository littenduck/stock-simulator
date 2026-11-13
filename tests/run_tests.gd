## Dependency-free test runner.
##   godot --headless --path . --script res://tests/run_tests.gd -- [dir] [--filter=text]
## Runs every tests/**/test_*.gd (or only under [dir]); exit code 1 if anything fails.
## Runs in _initialize (not _init) so the autoloads (EventBus, GameManager, SaveManager) exist when scripts compile.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var root := "res://tests"
	var filter := ""
	for a in args:
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
		elif not a.begins_with("--"):
			root = a
	var files: Array[String] = []
	_collect(root, files)
	files.sort()
	var total_checks := 0
	var failed := 0
	var ran := 0
	for path in files:
		if filter != "" and filter not in path:
			continue
		var script: GDScript = load(path)
		if script == null:
			print("FAIL  %s: cannot load (parse error?)" % path)
			failed += 1
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			if String(m.name).begins_with("test_"):
				methods.append(m.name)
		methods.sort()
		for m in methods:
			var t: TestCase = script.new()
			if t.has_method("before_each"):
				t.call("before_each")
			t.call(m)
			ran += 1
			total_checks += t.checks
			if t.failures.is_empty():
				print("ok    %s :: %s" % [path.get_file(), m])
			else:
				failed += 1
				for f in t.failures:
					print("FAIL  %s :: %s -> %s" % [path.get_file(), m, f])
	print("\n%d tests, %d checks, %d failed" % [ran, total_checks, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir_path):
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for d in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(d), out)
