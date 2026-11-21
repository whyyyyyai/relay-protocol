-- Read this first: Grok's Compass turns the public handoff into a short brief.
--
-- Purpose: show the current relay PRs, scheduler intent, data boundaries,
-- courier cautions, and next steps without asking a model API or reading
-- private chat files.
--
-- Reads: docs/GROK-HANDOFF.md by default, or a path supplied on the command
-- line. It only reads Markdown headings and their following text.
-- Writes: formatted text to stdout. It never edits files or contacts GitHub.
--
-- Run from the repository root:
--   ghc -Wall -O2 -o /tmp/grok-compass haskell/grok-compass/Main.hs
--   /tmp/grok-compass
--   /tmp/grok-compass --all
--   /tmp/grok-compass --section "Push-courier review"
--
-- Safety: use the public handoff only. Do not point this tool at private
-- message logs or credential files. It is a reader, not an authorization
-- source: the handoff itself says what needs the owner's decision.
--
-- Written by: Codex (2026-11-21)

module Main where

import Control.Exception (IOException, evaluate, try)
import Data.Char (isSpace, toLower)
import Data.List (dropWhileEnd, find)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

data View
  = KeySections
  | AllSections
  | OneSection String

-- Read the handoff path, validate it, and print the chosen briefing view.
main :: IO ()
main = do
  arguments <- getArgs
  case parseArguments arguments of
    Left problem -> do
      hPutStrLn stderr problem
      exitFailure
    Right (path, view) -> do
      readResult <- try (readStrictly path) :: IO (Either IOException String)
      case readResult of
        Left problem -> do
          hPutStrLn stderr ("grok-compass: cannot read " ++ path ++ ": " ++ show problem)
          exitFailure
        Right markdown -> renderBrief path view (parseSections (lines markdown))

-- Parse the optional input path and choose a compact, complete, or named view.
parseArguments :: [String] -> Either String (FilePath, View)
parseArguments [] = Right ("docs/GROK-HANDOFF.md", KeySections)
parseArguments [path] = Right (path, KeySections)
parseArguments ["--all"] = Right ("docs/GROK-HANDOFF.md", AllSections)
parseArguments ["--all", path] = Right (path, AllSections)
parseArguments ["--section", title] = Right ("docs/GROK-HANDOFF.md", OneSection title)
parseArguments ["--section", title, path] = Right (path, OneSection title)
parseArguments _ = Left usage

-- Keep the usage text next to argument parsing so help and errors stay in sync.
usage :: String
usage = unlines
  [ "Usage: grok-compass [--all | --section TITLE] [HANDOFF.md]"
  , "Default handoff: docs/GROK-HANDOFF.md"
  ]

-- Force the lazy file contents while the IO exception handler is still active.
readStrictly :: FilePath -> IO String
readStrictly path = do
  contents <- readFile path
  _ <- evaluate (length contents)
  pure contents

-- Split a Markdown document into level-two heading sections, preserving text.
parseSections :: [String] -> [(String, [String])]
parseSections [] = []
parseSections (line : rest)
  | isSectionHeading line =
      let (body, remaining) = span (not . isSectionHeading) rest
       in (trim (drop 3 line), body) : parseSections remaining
  | otherwise = parseSections rest

-- Recognize level-two headings while leaving smaller subheadings in the body.
isSectionHeading :: String -> Bool
isSectionHeading line = take 3 line == "## "

-- Print the selected handoff sections in a small terminal-friendly frame.
renderBrief :: FilePath -> View -> [(String, [String])] -> IO ()
renderBrief path view sections = do
  putStrLn "  .---- GROK'S COMPASS ----."
  putStrLn ("  | source: " ++ path)
  putStrLn "  | read-only · no API calls · public handoff only"
  putStrLn "  '-------------------------'
  case view of
    KeySections -> mapM_ (showNamed sections) keySectionNames
    AllSections -> mapM_ (showSection sections) sections
    OneSection title -> showNamed sections title
  putStrLn ""
  putStrLn "Use the linked PRs for current GitHub state; this brief is a snapshot."

-- The compact view shows the information Grok needs first to take over.
keySectionNames :: [String]
keySectionNames =
  [ "Current pull requests"
  , "Owner's publishing rule"
  , "Scheduler intent"
  , "Public and private message data"
  , "Push-courier review"
  , "Next steps"
  ]

-- Find a requested heading without requiring callers to match letter case.
showNamed :: [(String, [String])] -> String -> IO ()
showNamed sections title =
  case find ((== normalize title) . normalize . fst) sections of
    Nothing -> putStrLn ("\n## " ++ title ++ "\n  (section not found)")
    Just section -> showSection sections section

-- Print a heading and its non-empty body lines with a readable indent.
showSection :: [(String, [String])] -> (String, [String]) -> IO ()
showSection _ (title, body) = do
  putStrLn ("\n## " ++ title)
  mapM_ (putStrLn . ("  " ++) . trim) (filter (not . all isSpace) body)

-- Normalize headings so a case difference does not hide a section.
normalize :: String -> String
normalize = map toLower . trim

-- Remove leading and trailing whitespace while preserving interior spacing.
trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
