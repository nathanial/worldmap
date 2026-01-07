import Lake
open Lake DSL

package worldmap where
  leanOptions := #[
    ⟨`autoImplicit, false⟩,
    ⟨`relaxedAutoImplicit, false⟩
  ]

require afferent from git "https://github.com/nathanial/afferent" @ "v0.0.2"
require wisp from git "https://github.com/nathanial/wisp" @ "v0.0.1"
require cellar from git "https://github.com/nathanial/cellar" @ "v0.0.1"
require crucible from git "https://github.com/nathanial/crucible" @ "v0.0.3"

-- Link arguments for Metal/macOS (inherited pattern from afferent)
def commonLinkArgs : Array String := #[
  "-framework", "Metal",
  "-framework", "Cocoa",
  "-framework", "QuartzCore",
  "-framework", "Foundation",
  "-lobjc",
  "-L/opt/homebrew/lib",
  "-L/usr/local/lib",
  "-lfreetype",
  "-lassimp",
  "-lcurl",
  "-lc++"
]

@[default_target]
lean_lib Worldmap where
  roots := #[`Worldmap]

lean_lib Tests where
  roots := #[`Tests]
  globs := #[.submodules `Tests]

lean_exe worldmap where
  root := `Main
  moreLinkArgs := commonLinkArgs

lean_exe worldmap_tests where
  root := `Tests.Main
  moreLinkArgs := commonLinkArgs

@[test_driver]
lean_exe test where
  root := `Tests.Main
  moreLinkArgs := commonLinkArgs
