/-
  macOS Virtual Key Codes for Keyboard Input
  Based on Carbon Events.h / HIToolbox
-/
namespace Worldmap.KeyCode

-- macOS virtual key codes

-- Arrow keys
def arrowUp    : UInt16 := 126  -- 0x7E
def arrowDown  : UInt16 := 125  -- 0x7D
def arrowLeft  : UInt16 := 123  -- 0x7B
def arrowRight : UInt16 := 124  -- 0x7C

-- Number row (main keyboard)
def key0 : UInt16 := 29  -- 0x1D
def key1 : UInt16 := 18  -- 0x12
def key2 : UInt16 := 19  -- 0x13
def key3 : UInt16 := 20  -- 0x14
def key4 : UInt16 := 21  -- 0x15
def key5 : UInt16 := 23  -- 0x17
def key6 : UInt16 := 22  -- 0x16
def key7 : UInt16 := 26  -- 0x1A
def key8 : UInt16 := 28  -- 0x1C
def key9 : UInt16 := 25  -- 0x19

-- Symbols
def equal     : UInt16 := 24   -- 0x18 (= and +)
def minus     : UInt16 := 27   -- 0x1B (- and _)
def space     : UInt16 := 49   -- 0x31
def escape    : UInt16 := 53   -- 0x35
def returnKey : UInt16 := 36   -- 0x24
def delete    : UInt16 := 51   -- 0x33 (backspace)

-- Navigation
def home      : UInt16 := 115  -- 0x73
def end_      : UInt16 := 119  -- 0x77
def pageUp    : UInt16 := 116  -- 0x74
def pageDown  : UInt16 := 121  -- 0x79

-- Letters (for potential future use)
def keyW : UInt16 := 13   -- 0x0D
def keyA : UInt16 := 0    -- 0x00
def keyS : UInt16 := 1    -- 0x01
def keyD : UInt16 := 2    -- 0x02
def keyR : UInt16 := 15   -- 0x0F (reset)

/-- Convert a key code to a zoom level (0-9), returns none for non-numeric keys -/
def toZoomLevel (keyCode : UInt16) : Option Int :=
  if keyCode == key0 then some 10  -- 0 maps to zoom 10 (reasonable default)
  else if keyCode == key1 then some 1
  else if keyCode == key2 then some 2
  else if keyCode == key3 then some 3
  else if keyCode == key4 then some 4
  else if keyCode == key5 then some 5
  else if keyCode == key6 then some 6
  else if keyCode == key7 then some 7
  else if keyCode == key8 then some 8
  else if keyCode == key9 then some 9
  else none

end Worldmap.KeyCode
