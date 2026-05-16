let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/a3c59033a08c2eaef2cfba4a3c99fc9c192ca6d7/package.dhall
        sha256:18258ef583580a897f4af3e7c86db0342afb42fb40efc535b217ba1089230141

in  Schema.Project::{
    , project = Schema.ProjectIdentity::{
      , name = "haskell-nix"
      , namespace = "shinzui"
      , type = Schema.PackageType.Library
      , language = Schema.Language.Nix
      , lifecycle = Schema.Lifecycle.Active
      , description = Some
          "Version-scoped Haskell patch management flake for multi-repository Nix builds"
      , domains = [ "Build", "Haskell", "Nix" ]
      }
    , repos =
      [ Schema.Repo::{
        , name = "haskell-nix"
        , github = Some "shinzui/haskell-nix"
        }
      ]
    }
