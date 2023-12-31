module Demo.Samples.DocsEmbed.Main
  ( embedKeys
  , main
  ) where

import Prelude

import Chameleon as C
import Chameleon.Impl.Halogen (HalogenHtml, runHalogenHtml)
import Chameleon.Impl.Halogen as HI
import Chameleon.Styled (class HtmlStyled, StyleT, runStyleT, styleNode)
import Data.Array as Array
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), Replacement(..))
import Data.String as Str
import Data.Tuple.Nested ((/\))
import Dodo (Doc, plainText, twoSpaces)
import Dodo as Dodo
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class.Console (error)
import Halogen as H
import Halogen as Halogen
import InteractiveData (AppMsg, AppState, DataUI, IDHtmlT, IDSurface, WrapMsg, WrapState)
import InteractiveData as ID
import InteractiveData.Entry (InteractiveDataApp)
import Manual.ComposingDataUIs.Arrays as Arrays
import Manual.ComposingDataUIs.CustomTypes as CustomType
import Manual.ComposingDataUIs.MaybeAndFriends as MaybeAndFriends
import Manual.ComposingDataUIs.Newtypes.JsonEscape as JsonEscape
import Manual.ComposingDataUIs.Newtypes.SimpleNewtypes as SimpleNewtypes
import Manual.ComposingDataUIs.Newtypes.Validation as Validation
import Manual.ComposingDataUIs.Primitives as Primitives
import Manual.ComposingDataUIs.Records as Records
import Manual.ComposingDataUIs.Variants as Variants
import Manual.Polymorphic as Polymorphic
import Manual.Polymorphic.DefineTypeClass as DefineTypeClass
import Manual.WritingDataUIs.Trivial as Trivial
import PureScript.CST (RecoveredParserResult(..), parseExpr)
import PureScript.CST.Types (Expr)
import Tidy (FormatDoc, defaultFormatOptions, formatExpr, toDoc)

foreign import getQueryString :: Effect String

embeds :: Map String (Effect Unit)
embeds =
  Map.fromFoldable
    -- Primitives
    [ "int" /\ app { showMenuOnStart: false } Primitives.demoInt
    , "string" /\ app { showMenuOnStart: false } Primitives.demoString
    , "boolean" /\ app { showMenuOnStart: false } Primitives.demoBoolean
    , "number" /\ app { showMenuOnStart: false } Primitives.demoNumber

    -- Arrays
    , "array" /\ app { showMenuOnStart: true } Arrays.demo

    -- Record
    , "record" /\ app { showMenuOnStart: true } Records.demoRecord

    -- Maybe and friends
    , "maybe" /\ app { showMenuOnStart: true } MaybeAndFriends.demoMaybe
    , "either" /\ app { showMenuOnStart: true } MaybeAndFriends.demoEither
    , "tuple" /\ app { showMenuOnStart: true } MaybeAndFriends.demoTuple
    , "unit" /\ app { showMenuOnStart: true } MaybeAndFriends.demoUnit

    -- Variant
    , "variant" /\ app { showMenuOnStart: true } Variants.demoVariant

    -- Custom type
    , "customType" /\ app { showMenuOnStart: true } CustomType.demoCustomType

    -- Simple newtypes
    , "simpleNewtype" /\ app { showMenuOnStart: false } SimpleNewtypes.demo

    -- Validation
    , "validation" /\ app { showMenuOnStart: false } Validation.demo

    -- Json Escape
    , "jsonEscape" /\ app { showMenuOnStart: false } JsonEscape.demo

    -- Trivial Data UI
    , "trivial" /\ app { showMenuOnStart: false } Trivial.demo

    -- Polymorphic
    , "polymorphic" /\ app { showMenuOnStart: false } Polymorphic.demo
    , "customClass" /\ app { showMenuOnStart: false } DefineTypeClass.demo
    ]

embedKeys :: Array String
embedKeys = Array.fromFoldable $ Map.keys embeds

viewWrapper :: forall html msg. HtmlStyled html => { atDataStr :: String, atInteractiveData :: html msg } -> html msg
viewWrapper { atInteractiveData, atDataStr } =
  let
    el =
      { root: styleNode C.div
          [ "display: grid"
          , "grid-template-rows: minmax(0, 1fr) auto"
          , "height: 100%"
          , "background: hsl(200, 7%, 8%);"
          , "box-sizing: border-box"
          , "position: fixed"
          , "top: 0"
          , "left: 0"
          , "right: 0"
          , "bottom: 0"
          ]
      , atInteractiveData: styleNode C.div
          [ "border:1px solid #9f9f9f"
          , "border-radius: 5px"
          , "overflow: hidden"
          , "max-width: 800px"
          ]
      , atDataStr: styleNode C.pre
          [ "font-size: 10px"
          , "color: #c3c3c3"
          , "padding: 0 10px"
          , "height: 80px"
          , "overflow: auto"
          , "background: #1d1f21"
          ]
      }
  in
    el.root []
      [ el.atInteractiveData []
          [ atInteractiveData ]
      , el.atDataStr []
          [ C.text atDataStr ]
      ]

printVal :: forall a. Show a => a -> String
printVal val =
  let
    valStr :: String
    valStr = show val

    parseResult :: RecoveredParserResult Expr
    parseResult = parseExpr valStr
  in
    case parseResult of
      ParseSucceeded expr -> printExpr expr
      ParseSucceededWithErrors _ _ -> valStr
      ParseFailed _ -> valStr

printExpr :: Expr Void -> String
printExpr expr =
  let
    formatDoc :: forall b. FormatDoc b
    formatDoc = formatExpr defaultFormatOptions expr

    doc :: forall b. Doc b
    doc = toDoc formatDoc

    dodoOptions :: Dodo.PrintOptions
    dodoOptions = twoSpaces
      { pageWidth = 50
      }

  in
    Dodo.print plainText dodoOptions doc

mkHalogenComponent
  :: forall q i o msg sta a
   . Show a
  => InteractiveDataApp (StyleT HalogenHtml) (AppMsg (WrapMsg msg)) (AppState (WrapState sta)) a
  -> Halogen.Component q i o Aff
mkHalogenComponent { ui, extract } =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval { handleAction = handleAction }
    }
  where
  initialState _ = ui.init

  render state =
    runHalogenHtml $ runStyleT $ viewWrapper
      { atInteractiveData: ui.view state
      , atDataStr: printVal $ extract state
      }

  handleAction msg = do
    H.modify_ $ ui.update msg

summary
  :: forall q i o
   . Halogen.Component q i o Aff
summary =
  H.mkComponent
    { initialState
    , render
    , eval: H.mkEval $ H.defaultEval
    }
  where
  initialState _ = unit

  render state =
    runHalogenHtml $ runStyleT $ view state

  view _ =
    C.div []
      ( embedKeys # map
          ( \key ->
              C.div []
                [ C.a [ C.href ("?" <> key) ] [ C.text key ]
                ]
          )
      )

app
  :: forall a
   . Show a
  => { showMenuOnStart :: Boolean }
  -> DataUI (IDSurface (IDHtmlT (StyleT HalogenHtml)))
       WrapMsg
       WrapState
       _
       _
       a
  -> Effect Unit
app { showMenuOnStart } dataUi = do
  let
    sampleApp =
      ID.toApp
        { name: ""
        , initData: Nothing
        , fullscreen: false
        , showLogo: false
        , showMenuOnStart
        }
        dataUi

  HI.uiMountAtId "root" $ mkHalogenComponent sampleApp

main :: Effect Unit
main = do
  queryString <- getQueryString

  case queryString of
    "" -> HI.uiMountAtId "root" summary
    _ -> do
      let
        embedId = Str.replace (Pattern "?") (Replacement "") queryString

        maybeRunEmbed = Map.lookup embedId embeds

      case maybeRunEmbed of
        Just runEmbed -> runEmbed
        Nothing -> do
          error "Invalid query string"
          pure unit
