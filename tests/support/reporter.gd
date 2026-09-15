extends RefCounted

var passed: int = 0
var failures: Array[String] = []

var _suite: String = ""
var _case: String = ""

func begin_suite(suite_name: String) -> void:
	_suite = suite_name

func begin_case(case_name: String) -> void:
	_case = case_name

func check(condition: bool, message: String) -> bool:
	if condition:
		passed += 1
		return true
	failures.append("[%s] %s -- %s" % [_suite, _case, message])
	return false

func equal(actual: Variant, expected: Variant, message: String) -> bool:
	return check(actual == expected, "%s (actual=%s expected=%s)" % [message, actual, expected])

func at_least(actual: float, minimum: float, message: String) -> bool:
	return check(actual >= minimum, "%s (actual=%.3f minimum=%.3f)" % [message, actual, minimum])

func at_most(actual: float, maximum: float, message: String) -> bool:
	return check(actual <= maximum, "%s (actual=%.3f maximum=%.3f)" % [message, actual, maximum])
