let Schema = https://raw.githubusercontent.com/shinzui/mori-schema/a3c59033a08c2eaef2cfba4a3c99fc9c192ca6d7/package.dhall
      sha256:18258ef583580a897f4af3e7c86db0342afb42fb40efc535b217ba1089230141

let AgentPlans = https://raw.githubusercontent.com/shinzui/mori-schema/a3c59033a08c2eaef2cfba4a3c99fc9c192ca6d7/extensions/agent-plans/package.dhall
      sha256:0b567808087da1924fb121df044c9432f676bb81305d5373809e3182d054943b

in  AgentPlans.AgentPlansCatalog::{
    , plans =
      [ AgentPlans.ExposedPlan::{
        , kind = AgentPlans.PlanKind.MasterPlan
        , file = "docs/masterplans/4-coordinate-horizon-inspired-haskell-nix-performance-and-reliability-improvements.md"
        , status = AgentPlans.PlanStatus.NotStarted
        , owner = None Text
        , summary = None Text
        , dependencies =
          [ AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/18-accelerate-application-code-compilation-in-nix-builds"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/19-pre-generate-complete-locked-nix-haskell-dependency-recipes"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/20-build-project-development-shells-from-retained-runtime-package-sets"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/21-manage-compatibility-exceptions-and-verify-their-continued-necessity"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix-dev/masterplans/2-publish-verified-haskell-toolchain-capabilities-and-support-evidence"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix-dev/plans/4-publish-compiler-capabilities-and-an-explicit-platform-support-matrix"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix-dev/plans/5-exercise-ghc-cabal-and-hls-in-toolchain-compatibility-checks"
            }
          ]
        }
      , AgentPlans.ExposedPlan::{
        , kind = AgentPlans.PlanKind.ExecPlan
        , file = "docs/plans/18-accelerate-application-code-compilation-in-nix-builds.md"
        , status = AgentPlans.PlanStatus.NotStarted
        , owner = None Text
        , summary = None Text
        , dependencies =
          [ AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/19-pre-generate-complete-locked-nix-haskell-dependency-recipes"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/21-manage-compatibility-exceptions-and-verify-their-continued-necessity"
            }
          ]
        }
      , AgentPlans.ExposedPlan::{
        , kind = AgentPlans.PlanKind.ExecPlan
        , file = "docs/plans/19-pre-generate-complete-locked-nix-haskell-dependency-recipes.md"
        , status = AgentPlans.PlanStatus.NotStarted
        , owner = None Text
        , summary = None Text
        , dependencies =
          [ AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/21-manage-compatibility-exceptions-and-verify-their-continued-necessity"
            }
          ]
        }
      , AgentPlans.ExposedPlan::{
        , kind = AgentPlans.PlanKind.ExecPlan
        , file = "docs/plans/20-build-project-development-shells-from-retained-runtime-package-sets.md"
        , status = AgentPlans.PlanStatus.NotStarted
        , owner = None Text
        , summary = None Text
        , dependencies =
          [ AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Hard
            , target = "mori://shinzui/haskell-nix-dev/plans/4-publish-compiler-capabilities-and-an-explicit-platform-support-matrix"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/21-manage-compatibility-exceptions-and-verify-their-continued-necessity"
            }
          ]
        }
      , AgentPlans.ExposedPlan::{
        , kind = AgentPlans.PlanKind.ExecPlan
        , file = "docs/plans/21-manage-compatibility-exceptions-and-verify-their-continued-necessity.md"
        , status = AgentPlans.PlanStatus.NotStarted
        , owner = None Text
        , summary = None Text
        , dependencies =
          [ AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/9-generate-the-nix-package-set-from-the-cohort-freeze-and-guard-version-parity"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/16-create-the-keiro-runtime-package-set-and-compose-applications-on-it"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix/plans/19-pre-generate-complete-locked-nix-haskell-dependency-recipes"
            }
          , AgentPlans.PlanDependency::{
            , kind = AgentPlans.DependencyKind.Integration
            , target = "mori://shinzui/haskell-nix-dev/masterplans/2-publish-verified-haskell-toolchain-capabilities-and-support-evidence"
            }
          ]
        }
      ]
    }
