-- Read Cabal's resolved flag assignment after an exact configure replay.
-- mori://haskell/cabal/packages/Cabal: LocalBuildInfo.flagAssignment, not the
-- user-supplied flags in ConfigFlags (which omit automatic/default choices).
import Distribution.Simple.Configure (getPersistBuildConfig)
import Distribution.Simple.LocalBuildInfo (flagAssignment, withPrograms)
import Distribution.Simple.Program.Builtin (hsc2hsProgram)
import Distribution.Simple.Program.Db (lookupProgram)
import Distribution.Simple.Program.Types (programVersion, programPath)
import Distribution.Pretty (prettyShow)
import System.Environment (getArgs)
import Distribution.Types.Flag (unFlagAssignment, unFlagName)
import Distribution.Utils.Path (makeSymbolicPath)

main :: IO ()
main = do
    configured <- getPersistBuildConfig Nothing (makeSymbolicPath "dist")
    [output] <- getArgs
    writeFile (output ++ "/programs") $ case lookupProgram hsc2hsProgram (withPrograms configured) of
        Nothing -> ""
        Just program -> "hsc2hs\t" ++ maybe "unknown" prettyShow (programVersion program)
            ++ "\t" ++ programPath program ++ "\n"
    mapM_ (\(name, enabled) -> putStrLn (unFlagName name ++ "=" ++ show enabled))
        (unFlagAssignment (flagAssignment configured))
