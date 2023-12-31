module InteractiveData.App.WrapApp
  ( AppMsg(..)
  , AppState(..)
  , AppSelfMsg(..)
  , wrapApp
  ) where

import Prelude

import Chameleon as C
import Chameleon.Transformers.Ctx.Class (class Ctx, putCtx, withCtx)
import Chameleon.Transformers.OutMsg.Class (runOutMsg)
import Data.Array.NonEmpty as NEA
import Data.Either (Either(..), either, note)
import Data.Maybe (Maybe(..))
import Data.Newtype (un)
import Data.These (These(..))
import Data.Tuple.Nested (type (/\))
import DataMVC.Types (DataPathSegment, DataResult, DataUI(..), DataUiInterface(..))
import DataMVC.Types.DataUI (applyWrap, runDataUi)
import InteractiveData.App.FastForward.Standalone as FastForwardStandalone
import InteractiveData.App.UI.Body as UIBody
import InteractiveData.App.UI.Footer as UIFooter
import InteractiveData.App.UI.Header as UIHeader
import InteractiveData.App.UI.Layout as UILayout
import InteractiveData.App.UI.Menu (MenuSelfMsg)
import InteractiveData.App.UI.Menu as UIMenu
import InteractiveData.App.UI.NotFound as UINotFound
import InteractiveData.App.UI.SideBar as UISideBar
import InteractiveData.App.UI.Types.SumTree (SumTree, sumTree)
import InteractiveData.Core
  ( class IDHtml
  , DataTree(..)
  , DataTreeChildren(..)
  , IDOutMsg(..)
  , IDSurface(..)
  , TreeMeta
  , ViewMode(..)
  , IDViewCtx
  )
import InteractiveData.Core.Types.DataPathExtra (dataPathFromStrings, dataPathToStrings)
import InteractiveData.Core.Types.DataTree as DT
import InteractiveData.Core.Types.IDSurface (runIdSurface)

--------------------------------------------------------------------------------
--- Types
--------------------------------------------------------------------------------

newtype AppState sta = AppState
  { selectedPath :: Array String
  , menu :: UIMenu.MenuState
  , dataState :: sta
  , showMenu :: Boolean
  , showErrors :: Boolean
  }

type AppMsg msg = These (AppSelfMsg msg) IDOutMsg

data AppSelfMsg msg
  = SetSelectedPath (Array String)
  | DataMsg msg
  | MenuMsg (UIMenu.MenuMsg (AppSelfMsg msg))
  | SetShowMenu Boolean
  | SetShowErrors Boolean

type DataTrees html msg =
  { global ::
      { dataTree :: DataTree html msg
      , sumTree :: SumTree
      , meta :: TreeMeta
      , selectedDataPath :: Array DataPathSegment
      }
  , selected ::
      { dataTree :: DataTree html msg
      , meta :: TreeMeta
      }
  }

--------------------------------------------------------------------------------
--- View
--------------------------------------------------------------------------------

view
  :: forall html msg sta
   . Ctx IDViewCtx html
  => IDHtml html
  => (sta -> DataTree html msg)
  -> AppState sta
  -> DataTree html (AppMsg msg)
view view' state@(AppState { selectedPath }) =
  let
    eitherDataTrees :: Either String (DataTrees html msg)
    eitherDataTrees = getDataTrees view' state

    view'' :: html (AppSelfMsg msg)
    view'' = case eitherDataTrees of
      Left reason ->
        viewNotFound { selectedPath, reason }

      Right dataTrees ->
        viewFound dataTrees state

    viewOut :: html (AppMsg msg)
    viewOut = runOutMsg view''
  in
    DataTree
      { view: viewOut
      , actions: []
      , children: Fields []
      , meta: Nothing
      , text: Nothing
      }

viewNotFound
  :: forall html msg
   . IDHtml html
  => { selectedPath :: Array String, reason :: String }
  -> html (AppSelfMsg msg)
viewNotFound { selectedPath, reason } =
  UILayout.view
    { viewHeader: C.noHtml
    , viewBody:
        UINotFound.view
          { path: selectedPath
          , onBackToHome: SetSelectedPath mempty
          , reason
          }
    , viewSidebar: Nothing
    , viewFooter: Nothing
    }

viewFound
  :: forall html msg sta
   . Ctx IDViewCtx html
  => IDHtml html
  => DataTrees html msg
  -> AppState sta
  -> html (AppSelfMsg msg)
viewFound { global, selected } (AppState { showErrors, menu, showMenu }) =
  let
    DataTree { text } = selected.dataTree

    header :: html (AppSelfMsg msg)
    header =
      UIHeader.view
        { dataPath: global.selectedDataPath
        , onSelectPath: SetSelectedPath <<< dataPathToStrings
        , showMenu
        , onSetShowMenu: SetShowMenu
        , typeName: selected.meta.typeName
        , text
        }

    sidebar :: html (AppSelfMsg msg)
    sidebar =
      UISideBar.view
        { menu: map MenuMsg $
            UIMenu.view
              { onSelectPath: SetSelectedPath
              , tree: global.sumTree
              }
              menu
        }

    trivialTrees :: Array (Array DataPathSegment /\ DataTree html msg)
    trivialTrees = DT.digTrivialTrees
      global.selectedDataPath
      selected.dataTree

    viewContent' :: html (AppSelfMsg msg)
    viewContent' = withCtx \ctx ->
      case ctx.viewMode of
        Inline ->
          viewContent
        Standalone ->
          map DataMsg $ FastForwardStandalone.view trivialTrees

    viewContent :: html (AppSelfMsg msg)
    viewContent = selected.dataTree # un DataTree # _.view # map DataMsg

    body :: html (AppSelfMsg msg)
    body = UIBody.view
      { viewContent: viewContent' }

    footer :: html (AppSelfMsg msg)
    footer =
      UIFooter.view
        { errors: either NEA.toArray (\_ -> []) global.meta.errored
        , onSelectPath: SetSelectedPath <<< dataPathToStrings
        , isExpanded: showErrors
        , onChangeIsExpanded: SetShowErrors
        }

  in
    withCtx \(ctx :: IDViewCtx) ->
      let
        viewCtx :: IDViewCtx
        viewCtx =
          ctx
            { path = global.selectedDataPath
            , selectedPath = global.selectedDataPath
            , viewMode = Standalone
            }
      in
        putCtx viewCtx
          $ UILayout.view
              { viewHeader: header
              , viewSidebar: if showMenu then Just sidebar else Nothing
              , viewBody: body
              , viewFooter: Just footer
              }

getDataTrees
  :: forall html msg sta
   . Ctx IDViewCtx html
  => IDHtml html
  => (sta -> DataTree html msg)
  -> AppState sta
  -> Either String (DataTrees html msg)
getDataTrees view' (AppState { dataState, selectedPath }) = do

  -- Global

  let
    globalDataTree :: DataTree html msg
    globalDataTree = view' dataState

  selectedDataPath :: Array DataPathSegment <-
    dataPathFromStrings selectedPath globalDataTree
      # note "Selected path not found"

  globalMeta :: TreeMeta <-
    globalDataTree # un DataTree # _.meta
      # note "Global meta not found"

  sumTree <- sumTree globalDataTree <#> _.tree
    # note "Sum tree not found"

  -- Selected

  selectedDataTree :: DataTree html msg <-
    DT.find selectedDataPath globalDataTree
      # note "Selected data tree not found"

  selectedMeta :: TreeMeta <-
    selectedDataTree # un DataTree # _.meta
      # note "Selected meta not found"

  pure
    { global:
        { dataTree: globalDataTree
        , sumTree
        , selectedDataPath
        , meta: globalMeta
        }
    , selected:
        { dataTree: selectedDataTree
        , meta: selectedMeta
        }
    }

--------------------------------------------------------------------------------
--- Update
--------------------------------------------------------------------------------

update :: forall msg sta. (msg -> sta -> sta) -> AppMsg msg -> AppState sta -> AppState sta
update update' =
  updateThese
    updateThis
    updateThat

  where
  updateThis :: AppSelfMsg msg -> AppState sta -> AppState sta
  updateThis msg st@(AppState state) = case msg of
    SetSelectedPath path ->
      AppState state { selectedPath = path }

    DataMsg msg' ->
      AppState state { dataState = update' msg' state.dataState }

    MenuMsg msg' ->
      updateThese
        ( \(msg'' :: MenuSelfMsg) (AppState st') ->
            AppState st' { menu = UIMenu.update msg'' st'.menu }
        )
        (\(msg'' :: AppSelfMsg msg) -> update update' (This msg''))
        msg'
        st

    SetShowMenu showMenu ->
      AppState state { showMenu = showMenu }

    SetShowErrors showErrors ->
      AppState state { showErrors = showErrors }

  updateThat :: IDOutMsg -> AppState sta -> AppState sta
  updateThat outMsg (AppState state) =
    case outMsg of
      GlobalSelectDataPath path -> AppState state { selectedPath = path }

--------------------------------------------------------------------------------
--- Init
--------------------------------------------------------------------------------

init
  :: forall sta a
   . { showMenu :: Boolean }
  -> (Maybe a -> sta)
  -> Maybe a
  -> AppState sta
init { showMenu } init' opt = AppState
  { selectedPath: []
  , dataState: init' opt
  , menu: UIMenu.init
  , showMenu
  , showErrors: false
  }

--------------------------------------------------------------------------------
--- Extract
--------------------------------------------------------------------------------

extract :: forall sta a. (sta -> DataResult a) -> AppState sta -> DataResult a
extract extract' (AppState { dataState }) = extract' dataState

--------------------------------------------------------------------------------
--- DataUI
--------------------------------------------------------------------------------

wrapApp
  :: forall html fm fs msg sta a
   . Ctx IDViewCtx html
  => IDHtml html
  => { showMenuOnStart :: Boolean }
  -> DataUI (IDSurface html) fm fs msg sta a
  -> DataUI (IDSurface html) fm fs (AppMsg (fm msg)) (AppState (fs sta)) a
wrapApp { showMenuOnStart } dataUi' =
  DataUI \ctx ->
    let
      dataUi'' :: DataUI (IDSurface html) fm fs (fm msg) (fs sta) a
      dataUi'' = applyWrap dataUi'

      itf_ :: DataUiInterface (IDSurface html) (fm msg) (fs sta) a
      itf_ = runDataUi dataUi'' ctx

      DataUiInterface itf = itf_

      view' :: AppState (fs sta) -> IDSurface html (AppMsg (fm msg))
      view' state = IDSurface \idSurfaceCtx ->
        view
          (itf.view >>> runIdSurface idSurfaceCtx)
          state
    in
      DataUiInterface
        { name: itf.name
        , view: view'
        , update: update itf.update
        , init: init { showMenu: showMenuOnStart } itf.init
        , extract: extract itf.extract
        }

--------------------------------------------------------------------------------
--- Utils
--------------------------------------------------------------------------------

-- | Update `This` with `f1`, `That` with `f2` and `Both` with `f1` and `f2` composed
updateThese :: forall a b z. (a -> (z -> z)) -> (b -> (z -> z)) -> These a b -> (z -> z)
updateThese f1 f2 = case _ of
  This x -> f1 x
  That y -> f2 y
  Both x y -> f1 x >>> f2 y
