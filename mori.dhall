let Schema =
      https://raw.githubusercontent.com/shinzui/mori-schema/cf5a5cced1aa08deee6c583ac2fbef79e8c06648/package.dhall
        sha256:da11f2da781dca8824039c41ef27177193c060099800221c490d961fd07061c2

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
