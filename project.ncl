# Use cases I'd like to make easy (heavily biased by the things I like to do):
#
# - Sane default for native development (the build shell uses the stable rust minimal profile,
#   the dev shell uses the stable rust default profile, plus rust-analyzer).
#
# - Easy addition of tier 1 & 2 targets for cross-compilation.
#
# - Easy addition of extra components. Components that are added in the build shell should be
#   propagated to the dev shell also.
#
#   One fenix papercut that I'd like to avoid here is that fenix doesn't make it
#   so easy/discoverable to just add a component to an existing toolchain. Like,
#   if I'm using `stable.defaultToolchain` and I want to add rust-analyzer then
#   I either need to use `stable.withComponents` (and re-list all the components
#   that were already in the default toolchain) or use `combine`.
#
# - Use dev on nightly and build on stable (mostly useful for testing with miri, which doesn't
#   exist on stable.
#
# Known issues:
# - accidentally writing `Rust & { channel = 'nightly }` instead of `Rust & { build.channel = 'nightly }`
#   gives the dreaded "boost::bad_format_string: format-string is ill-formed" error
# - auto-completion for targets would be real nice
let inputs = import "./nickel.lock.ncl" in
let organist = inputs.organist in
let Targets = import "./targets.ncl" in
let RustShell = {
  channel | [| 'stable, 'beta, 'nightly |]
          | doc "The rust channel"
          | default
          = 'stable,
  extraTargets | doc "Extra targets to install, for cross-compilation"
               = Targets,

  components | doc "Rust components to install"
             = {
    rustc | default = true,
    cargo | default = true,
    rust-std | default = true,
    rust-docs | default = false,
    rustfmt | default = false,
    rust-analyzer | default = false,
    clippy | default = false,
    miri | default = false,
    rust-src | default = false,
  },

  packages.rust-toolchain =
    # Maybe we should default to "complete" instead of "latest"? Tier 2 targets only
    # have "latest", though...
    let toolchain = if channel == 'nightly then "latest" else std.string.from_enum channel in
    let targetNames = std.record.filter (fun n v => v) extraTargets |> std.record.fields in
    let targets = std.array.map (fun x => organist.import_nix "fenix#targets.%{x}.%{toolchain}.rust-std") targetNames in
    let componentNames =
      std.record.filter (fun name value => value) components
      |> std.record.fields
    in
    organist.nix.derivation.CallNix & {
      function = "{ withComponents, components }: withComponents components",
      args = {
        withComponents = organist.import_nix "fenix#combine",
        components =
          componentNames
          |> std.array.map (fun x => organist.import_nix "fenix#%{toolchain}.%{x}")
          |> std.array.concat targets,
      },
    },
}
in
let Rust = {
  build = RustShell,
  dev = RustShell & {
          # This should probably have the default priority, but it gets merged with
          # build.components and if it's default then they clash.
          components = {
            rust-docs = true,
            rustfmt = true,
            clippy = true,
            rust-analyzer = true,
          }
        },
}
in
{
  shells = organist.shells.Bash,

  # LSP TODO: hovering on build.channel doesn't work (but autocomplete does, as long as the record is complete enough to parse)
  # LSP TODO: autocomplete for enum variants

  # Examples
  # Native development, nightly
  shells = Rust & { build.channel = 'nightly },
  # Native development, nightly + miri (but only for dev)
  # shells = Rust & { build.channel = 'nightly, dev.components.miri = true },
  # Cross-compiling for wasm
  # shells = Rust & { build.extraTargets.wasm32-unknown-unknown = true },
}
  | organist.OrganistExpression
