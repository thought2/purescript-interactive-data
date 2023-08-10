module InteractiveData.App.UI.Body
  ( ViewBodyCfg
  , viewBody
  ) where

import InteractiveData.Core.Prelude

import Chameleon as C

type ViewBodyCfg (html :: Type -> Type) msg =
  { viewContent :: html msg
  }

viewBody :: forall html msg. IDHtml html => ViewBodyCfg html msg -> html msg
viewBody { viewContent } =
  let
    el =
      { body: styleNode C.div unit
      , content: styleNode C.div
          [ "padding: 10px"
          , "padding-left: 20px"
          , "max-width: 600px"
          ]
      }
  in
    el.body []
      [ el.content []
          [ viewContent ]
      ]