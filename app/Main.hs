module Main where

import qualified Data.Map as M
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Lazy as LT
import Foreign.Marshal.Alloc (callocBytes, free)
import Foreign.Ptr (Ptr)
import Lucid (renderText, renderToFile)
import System.IO (BufferMode (LineBuffering, NoBuffering), hSetBuffering, stderr, stdout)
import Text.Read (readMaybe)
import Ui
  ( Model (..),
    defaultTimeLimit,
    renderClosedAndNewBlock,
    renderFinishedContainer,
    renderHomepage,
    renderTimer,
    renderTimesUpContainer,
  )

type QueryMap = Map Text [Text]

handler :: String -> IO String
handler input = do
  putStrLn ("Got input: " ++ input)

  let (path, _) =
        case break (== '?') input of
          (p, '?' : q) -> (p, q)
          (p, _) -> (p, "")

  let qMap = parseQuery $ T.pack input
  let model = buildModel qMap
  let timeRemaining = lookupInt "timeRemaining" qMap

  let html =
        case path of
          "/" ->
            renderHomepage
          "/reset-timer" ->
            renderTimer defaultTimeLimit model
          "/close-block" ->
            renderClosedAndNewBlock model
          "/finish" ->
            renderFinishedContainer model
          "/times-up" ->
            renderTimesUpContainer model
          "/tick" -> do
            case timeRemaining of
              Just n -> renderTimer (n - 1) model
              Nothing -> error "/tick timeRemaining missing!"
          _ -> error $ "Unknown route: " ++ path

  return . LT.unpack . renderText $ html

parseQuery :: T.Text -> QueryMap
parseQuery url = Map.fromListWith (flip (++)) keyValuePairs --  (flip (++)) to ensure correct order of entries
  where
    -- Drop everything up to and including the '?'
    -- Note, we use T.drop 1 because of T.breakOn, e.g., T.breakOn "::" "a::b::c" == ("a","::b::c")
    queryString = T.drop 1 $ snd $ T.breakOn "?" url

    -- Split on '&' and discard any empty segments
    params = filter (/= "") $ T.splitOn "&" queryString

    -- Convert each "key=value" param to a (key, [value]) map entry
    keyValuePairs = map toEntry params

    toEntry param = (key, [value])
      where
        -- Split on the first '=' only, then drop the '=' from the tail
        (key, rest) = T.breakOn "=" param
        value = T.drop 1 rest

lookupInt :: T.Text -> QueryMap -> Maybe Int
lookupInt key qm =
  case M.lookup key qm of
    Just [v] -> readMaybe (T.unpack v)
    Just (v : vs) -> error $ "Got many values for " ++ show key ++ ": " ++ show (v : vs)
    _ -> Nothing

buildModel :: QueryMap -> Model
buildModel qm =
  Model
    { boxes = lookupList "boxes" qm
    }

lookupList :: T.Text -> QueryMap -> [T.Text]
lookupList = M.findWithDefault []

appInit :: IO ()
appInit = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering

callocBuffer :: Int -> IO (Ptr a)
callocBuffer = callocBytes

freeBuffer :: Ptr a -> IO ()
freeBuffer = free

main :: IO ()
main = do
  hSetBuffering stdout NoBuffering
  hSetBuffering stderr NoBuffering
  renderToFile "site/index.html" renderHomepage
