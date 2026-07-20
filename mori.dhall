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
    , skills =
      [ Schema.Skill::{
        , name = "update-family"
        , description =
            "Update one first-party Haskell package family to its latest GitHub HEAD (git sha) and latest Hackage releases by driving the haskell-nix-update CLI, then verify. Rewrites flake.lock and packages/first-party-lock.json for the named family only."
        , path = Some "agents/skills/update-family"
        , tools =
          [ Schema.SkillTool::{
            , name = "haskell-nix-update"
            , description = Some
                "Flake CLI that refreshes GitHub and Hackage package locks (nix run .#haskell-nix-update)"
            , languages = [ Schema.Language.Haskell ]
            }
          , Schema.SkillTool::{
            , name = "just"
            , description = Some
                "justfile recipes wrapping the updater CLI (preview, refresh, check, validate)"
            , languages = [ Schema.Language.Shell ]
            }
          ]
        , compatibility = Some
            "Requires nix, git, jq, and a Mori-registered local checkout of the family source"
        , metadata =
          [ { mapKey = "argument-hint", mapValue = "<family-name>" }
          , { mapKey = "user-invocable", mapValue = "true" }
          ]
        }
      ]
    }
