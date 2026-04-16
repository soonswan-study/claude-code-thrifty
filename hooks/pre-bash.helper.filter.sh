#!/bin/bash
# Filters test runner output (pytest, jest, Django test, vitest) to show only essential lines:
# - Session start / collection summary
# - Failures, errors, tracebacks
# - Final results (passed/failed counts)
awk '
BEGIN { pm=0 }

/^={2,}.*test session starts/ { pm=1 }
pm==1 { print; if (/^collected/) { pm=0; print "..." } next }

/^_{2,} FAILURES _{2,}$/ { pm=2 }
/^_{2,} .* _{2,}$/ && pm==0 { pm=2 }
/^={2,}.*short test summary/ { pm=2 }
pm==2 { print; next }

/^_{2,} ERRORS _{2,}$/ { pm=3 }
pm==3 { print; next }

/^={2,}/ && (pm==2 || pm==3) { print; pm=0; next }

/^(PASSED|FAILED|ERROR|={2,}.*(passed|failed|error))/ { print; next }

/^(Creating|Destroying) test database/ { print; next }
/^(Ran [0-9]+ test|OK$|OK \(|FAILED \(|Traceback|Error:|assert)/ { print; next }
/^(System check identified)/ { print; next }

/^(Tests:|Test Suites:|PASS |FAIL )/ { print; next }
/● / { pm=4 }
pm==4 { print; if (/^$/) pm=0; next }
'
