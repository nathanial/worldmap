/-
  Worldmap Test Suite
  Main entry point for running all tests.
-/
import Tests.TileCoord
import Tests.TileProvider
import Tests.Viewport
import Tests.Zoom
import Tests.RetryLogic
import Tests.TileCache
import Tests.Utils
import Crucible

open Crucible

def main : IO UInt32 := do
  IO.println "Worldmap Test Suite"
  IO.println "==================="
  IO.println ""

  let result ← runAllSuites

  IO.println ""
  IO.println "==================="

  if result != 0 then
    IO.println "Some tests failed!"
    return 1
  else
    IO.println "All tests passed!"
    return 0
