## Base class of every test file. Test methods are named test_*; before_each() runs before each.
## CONTRACT: frozen (lead). No external dependencies, runs with `scripts/test.sh`.
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var checks: int = 0


func assert_true(cond: bool, msg: String = "expected true") -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	assert_true(not cond, msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	checks += 1
	if actual != expected:
		failures.append("%s expected %s but got %s" % [msg, str(expected), str(actual)])


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	checks += 1
	if absf(actual - expected) > eps:
		failures.append("%s expected %s +/- %s but got %s" % [msg, str(expected), str(eps), str(actual)])


func assert_not_null(value: Variant, msg: String = "expected non-null") -> void:
	assert_true(value != null, msg)
