module Ui
  ( renderHomepage,
    renderTimer,
    HTML,
    Model (..),
    renderFinishedContainer,
    renderTimesUpContainer,
    renderClosedAndNewBlock,
    defaultTimeLimit,
  )
where

import Data.Text (Text, pack)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Lucid
import Lucid.Base (makeAttributes)

type HTML = Html ()

-- Existing UI Code

defaultRowsPerBlock :: Int
defaultRowsPerBlock = 5

defaultTimeLimit :: Int
defaultTimeLimit = 5

newtype Model
  = Model {boxes :: [Text]}
  deriving (Eq, Show, Generic)

renderHomepage :: HTML
renderHomepage = do
  pageHead
  pageBody

---- GET /

pageBody :: HTML
pageBody =
  div_ $ do
    h1_ "Vomit Draft Editor"
    p_ instructions
    form_
      [ hxPost_ "/finish",
        hxTarget_ . toIdSelector $ containerId,
        hxSwap_ "outerHTML",
        hxExt_ "serverless"
      ]
      $ div_ [idAttr containerId]
      $ do
        writableBlock
        submitButton

instructions :: HTML
instructions =
  toHtml -- safe (i.e., escapes strings)
    ( "Once you start typing you can only stop typing for "
        ++ show defaultTimeLimit
        ++ " seconds before your text is locked in!"
    )

submitButton :: HTML
submitButton = button_ [type_ "submit"] "Finalise"

-- Active writable block

writableBlock :: HTML
writableBlock =
  div_ [idAttr activeBlockId] $ do
    baseTextArea
      [ rows_ . toText $ defaultRowsPerBlock,
        hxPost_ "/reset-timer",
        hxTrigger_ onInputEdit,
        hxTarget_ . toIdSelector $ timerId,
        hxSwap_ "outerHTML",
        hxExt_ "serverless"
      ]
      mempty
    renderTimer defaultTimeLimit initModel
  where
    onInputEdit =
      T.intercalate
        ", "
        [ "input changed delay:300ms",
          "paste changed delay:300ms",
          "cut changed delay:300ms"
        ]

---- Both:
---- POST /tick?timeRemaining=x
---- POST /reset-timer

renderTimer :: Int -> Model -> HTML
renderTimer timeRemaining model =
  p_
    [ idAttr timerId,
      hxPost_ endpoint,
      hxTrigger_ "every 1000ms",
      hxTarget_ . toIdSelector $ target,
      hxSwap_ "outerHTML",
      hxExt_ "serverless",
      hxVals_ . pack $ "js:{timeRemaining: " ++ show timeRemaining ++ "}"
    ]
    $ toHtml ("Remaining: " ++ show timeRemaining)
  where
    activeBox = safeLastBox model

    (endpoint, target) = endpointAndTarget timeRemaining activeBox

    endpointAndTarget :: Int -> Text -> (Text, String)
    endpointAndTarget 1 "" = ("/times-up", containerId) -- times up: finish and merge what we have
    endpointAndTarget 1 _ = ("/close-block", activeBlockId) -- expire active block and add a new one
    endpointAndTarget _ _ = ("/tick", timerId) -- decreement timer

---- POST /close-block

renderClosedAndNewBlock :: Model -> HTML
renderClosedAndNewBlock m = do
  readOnlyBlock defaultRowsPerBlock (safeLastBox m)
  writableBlock

---- POST /times-up

renderTimesUpContainer :: Model -> HTML
renderTimesUpContainer model =
  div_ [idAttr containerId] $ do
    renderFinishedContainer model
    p_ "Times up!"

---- POST /finish

renderFinishedContainer :: Model -> HTML
renderFinishedContainer Model {boxes} =
  readOnlyBlock numRows mergedBox
  where
    numRows = countRows boxes
    mergedBox = mergeText boxes

readOnlyBlock :: Int -> Text -> HTML
readOnlyBlock numRows box =
  baseTextArea
    [ rows_ . toText $ numRows,
      readonly_ ""
    ]
    $ toHtml box

baseTextArea :: [Attributes] -> HTML -> HTML
baseTextArea attrs =
  textarea_ $
    name_ "boxes" : cols_ "100" : attrs

---- Model & Text Utils

safeLastBox :: Model -> Text
safeLastBox Model {boxes = []} = ""
safeLastBox Model {boxes} = last boxes

initModel :: Model
initModel = Model {boxes = []}

countRows :: [Text] -> Int
countRows boxes =
  let width = 100
      mergedLines :: [Text]
      mergedLines = T.splitOn "\n" $ mergeText boxes

      rowsForLine :: Text -> Int
      rowsForLine line =
        let len = T.length line
         in max 1 ((len + width - 1) `div` width)
   in sum (map rowsForLine mergedLines)

mergeText :: [Text] -> Text
mergeText = T.intercalate "\n\n"

toText :: (Show a) => a -> Text
toText = pack . show

emptyText :: Text
emptyText = pack ""

---- HTML Element Ids

containerId :: String
containerId = "container"

activeBlockId :: String
activeBlockId = "active"

timerId :: String
timerId = "timer"

idAttr :: String -> Attributes
idAttr = id_ . pack

toIdSelector :: String -> Text
toIdSelector idStr = pack $ "#" ++ idStr

---- Head

pageHead :: HTML
pageHead = doctypehtml_ $
  head_ $ do
    title_ "Vomit Draft Editor"
    meta_ [httpEquiv_ "Content-Type", content_ "text/html; charset=UTF-8"]
    meta_ [name_ "viewport", content_ "width=device-width, initial-scale=1"]
    meta_ [charset_ "UTF-8"]
    faviconLink
    css
    js

css :: HTML
css = do
  link_ [rel_ "stylesheet", href_ "./static/skeleton.css", type_ "text/css"]
  link_ [rel_ "stylesheet", href_ "./static/style.css", type_ "text/css"]

js :: HTML
js = do
  script_ [src_ "./static/htmx.min.js"] emptyText
  script_ [src_ "./static/htmx-serverless.js"] emptyText
  script_ [src_ "./static/wasm-dispatcher.js", type_ "module"] emptyText
  handlers ["/tick", "/reset-timer", "/finish", "/close-block", "/times-up"]

registerHandler :: Text -> Text
registerHandler route =
  "htmxServerless.handlers.set(\"" <> route <> "\", genHandler(\"" <> route <> "\"));"

handlers :: [Text] -> HTML
handlers routes =
  script_ [type_ "module"] $
    "import { genHandler } from \"./static/wasm-dispatcher.js\";\n"
      <> foldMap registerHandler routes

faviconLink :: HTML
faviconLink =
  link_
    [ rel_ "icon",
      href_ "favicon.ico",
      type_ "image/x-icon"
    ]

---- HTMX Bindings

hxPost_ :: Text -> Attributes
hxPost_ = makeAttributes "hx-post"

hxTrigger_ :: Text -> Attributes
hxTrigger_ = makeAttributes "hx-trigger"

hxTarget_ :: Text -> Attributes
hxTarget_ = makeAttributes "hx-target"

hxSwap_ :: Text -> Attributes
hxSwap_ = makeAttributes "hx-swap"

hxExt_ :: Text -> Attributes
hxExt_ = makeAttributes "hx-ext"

hxVals_ :: Text -> Attributes
hxVals_ = makeAttributes "hx-vals"
