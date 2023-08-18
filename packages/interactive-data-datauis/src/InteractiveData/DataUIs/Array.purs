module InteractiveData.DataUIs.Array
  ( ArrayMsg
  , ArrayState
  , CfgArray
  , array
  , array_
  , defaultCfgArray
  ) where

import InteractiveData.Core.Prelude

import Chameleon as C
import Data.Array as Array
import Data.FunctorWithIndex (mapWithIndex)
import Data.Traversable (traverse)
import DataMVC.Types.DataUI (applyWrap, runDataUi)
import InteractiveData.App.UI.ActionButton as UIActionButton
import InteractiveData.Core.Types.DataTree as DT
import InteractiveData.Core.Types.IDSurface (runIdSurface)

-------------------------------------------------------------------------------
--- Types
-------------------------------------------------------------------------------

data ArrayMsg msg
  = EntryMsg Int msg
  | AddAtEnd
  | AddAtStart
  | Delete Int
  | DeleteAll

newtype ArrayState sta = ArrayState (Array sta)

derive newtype instance Show sta => Show (ArrayState sta)

-------------------------------------------------------------------------------
--- Extract
-------------------------------------------------------------------------------

extract :: forall sta a. { extract :: sta -> DataResult a } -> ArrayState sta -> DataResult (Array a)
extract item (ArrayState s) =
  traverse item.extract s

-------------------------------------------------------------------------------
--- Init
-------------------------------------------------------------------------------

init :: forall sta a. { init :: Maybe a -> sta } -> Maybe (Array a) -> ArrayState sta
init item = case _ of
  Nothing -> ArrayState []
  Just a -> ArrayState $ map (Just >>> item.init) a

-------------------------------------------------------------------------------
--- Update
-------------------------------------------------------------------------------

update
  :: forall msg sta a
   . { update :: msg -> sta -> sta
     , init :: Maybe a -> sta
     }
  -> ArrayMsg msg
  -> ArrayState sta
  -> ArrayState sta
update item msg (ArrayState state) =
  case msg of
    EntryMsg index childMsg -> ArrayState
      let
        result :: Maybe (Array sta)
        result = Array.modifyAt index (item.update childMsg) state
      in
        fromMaybe state result

    AddAtStart -> ArrayState
      (Array.cons (item.init Nothing) state)

    AddAtEnd -> ArrayState
      (Array.snoc state (item.init Nothing))

    Delete index -> ArrayState
      let
        result :: Maybe (Array sta)
        result = Array.deleteAt index state
      in
        fromMaybe state result

    DeleteAll -> ArrayState []

-------------------------------------------------------------------------------
--- View
-------------------------------------------------------------------------------

view
  :: forall html msg sta
   . IDHtml html
  => { view :: sta -> html msg }
  -> ArrayState sta
  -> html (ArrayMsg msg)
view cfg (ArrayState items) =
  withCtx \ctx ->
    let
      el =
        { root: styleNode C.div
            [ "display: flex"
            , "flex-direction: column"
            , "gap: 20px"
            ]
        , item: C.div
        }

      countItems :: Int
      countItems = Array.length items
    in
      case ctx.viewMode of
        Standalone ->
          el.root []
            ( items #
                mapWithIndex \index item ->
                  el.item []
                    [ viewItem (pick cfg) index item
                    ]
            )
        Inline ->
          el.root []
            [ C.text (printItemsString countItems)
            ]

viewItem
  :: forall html msg sta
   . IDHtml html
  => { view :: sta -> html msg }
  -> Int
  -> sta
  -> html (ArrayMsg msg)
viewItem item index state =
  withCtx \ctx ->
    let
      el =
        { root: styleNode C.div
            [ "display: flex"
            , "align-items: flex-start"
            , "justify-content: space-between"
            ]
        , item: styleNode C.div
            [ "width: 100%"
            ]
        , actions: C.div
        }

      newPath = ctx.path <> [ SegField $ SegDynamicIndex index ]

    -- trivialTrees :: Array (Array DataPathSegment /\ DataTree html msg)
    -- trivialTrees = DT.digTrivialTrees
    --   newPath
    --   tree

    in
      el.root []
        [ el.item []
            [ putCtx ctx { path = newPath, viewMode = Inline }
                $ EntryMsg index
                <$> item.view state
            ]
        , el.actions []
            [ UIActionButton.view
                { dataAction: DataAction
                    { label: "Delete"
                    , msg: This $ Delete index
                    , description: "Delete an item from the Array"
                    }
                }
            ]
        ]

printItemsString :: Int -> String
printItemsString = case _ of
  0 -> "No items"
  1 -> "1 item"
  n -> show n <> " items"

-------------------------------------------------------------------------------
--- DataActions
-------------------------------------------------------------------------------

actions :: forall msg. Array (DataAction (ArrayMsg msg))
actions =
  [ DataAction
      { label: "Add at start"
      , msg: This $ AddAtStart
      , description: "Add an item at the start of the Array"
      }
  , DataAction
      { label: "Add at end"
      , msg: This $ AddAtEnd
      , description: "Add an item at the end of the Array"
      }
  , DataAction
      { label: "Delete all"
      , msg: This $ DeleteAll
      , description: "Delete all items from the Array"
      }
  ]

-------------------------------------------------------------------------------
--- DataUI
-------------------------------------------------------------------------------

type CfgArray :: forall k. k -> Type
type CfgArray msg =
  { text :: Maybe String
  }

defaultCfgArray :: CfgArray ArrayMsg
defaultCfgArray =
  { text: Nothing
  }

array
  :: forall opt html fm fs msg sta a
   . OptArgs (CfgArray ArrayMsg) opt
  => IDHtml html
  => opt
  -> DataUI (IDSurface html) fm fs msg sta a
  -> DataUI (IDSurface html) fm fs (ArrayMsg (fm msg)) (ArrayState (fs sta)) (Array a)
array opt dataUi =
  let
    cfg :: CfgArray ArrayMsg
    cfg = getAllArgs defaultCfgArray opt

    dataUi' :: DataUI (IDSurface html) fm fs (fm msg) (fs sta) a
    dataUi' = applyWrap dataUi

  in
    DataUI \ctx ->
      let
        DataUiInterface itf = runDataUi dataUi' ctx
      in
        DataUiInterface
          { name: "Array"
          , view: \state@(ArrayState items) -> IDSurface \srfCtx ->
              let
                view' :: fs sta -> html (fm msg)
                view' state' =
                  let
                    dataTree :: DataTree html (fm msg)
                    dataTree = runIdSurface srfCtx $ itf.view state'

                    DataTree { view } = dataTree
                  in
                    view

                mkChildren :: Int -> fs sta -> DataPathSegmentField /\ (DataTree html (ArrayMsg (fm msg)))
                mkChildren index state' =
                  let
                    dataTree :: DataTree html (fm msg)
                    dataTree = runIdSurface srfCtx $ itf.view state'
                  in
                    SegDynamicIndex index /\ map (EntryMsg index) dataTree
              in
                DataTree
                  { view: view { view: view' } state
                  , actions
                  , children: Fields (mapWithIndex mkChildren items)
                  , meta: Nothing
                  , text: cfg.text
                  }
          , extract: extract (pick itf)
          , update: update (pick itf)
          , init: init (pick itf)
          }

array_
  :: forall html fm fs msg sta a
   . IDHtml html
  => DataUI (IDSurface html) fm fs msg sta a
  -> DataUI (IDSurface html) fm fs (ArrayMsg (fm msg)) (ArrayState (fs sta)) (Array a)
array_ = array {}