module Internal.Settings exposing (..)

import Svg
import Time


type alias Settings =
    { canvasWidth : Float
    , canvasHeight : Float
    , nodeWidth : Float
    , nodeHeight : Float
    , level : Float
    , gutter : Float
    , centerOffset : ( Float, Float )
    , connectorStrokeAttributes : List (Svg.Attribute Never)
    , isDragAndDropEnabled : Bool
    , showPlaceholderLeaves : Bool
    , throttleMouseMoves : Maybe Time.Time
    , canDeactivate : Bool
    }


type Setting
    = NodeWidth Int
    | NodeHeight Int
    | CanvasWidth Int
    | CanvasHeight Int
    | Level Int
    | Gutter Int
    | CenterOffset Int Int
    | ConnectorStrokeAttributes (List (Svg.Attribute Never))
    | DragAndDrop Bool
    | PlaceholderLeaves Bool
    | ThrottleMouseMoves Time.Time
    | CanDeactivate Bool


apply : List Setting -> Settings -> Settings
apply newSettings settings =
    case newSettings of
        [] ->
            settings

        head :: tail ->
            apply tail
                (case head of
                    NodeWidth w ->
                        { settings | nodeWidth = toFloat w }

                    NodeHeight h ->
                        { settings | nodeHeight = toFloat h }

                    CanvasWidth w ->
                        { settings | canvasWidth = toFloat w }

                    CanvasHeight h ->
                        { settings | canvasHeight = toFloat h }

                    Level l ->
                        { settings | level = toFloat l }

                    Gutter g ->
                        { settings | gutter = toFloat g }

                    CenterOffset x y ->
                        { settings | centerOffset = ( toFloat x, toFloat y ) }

                    ConnectorStrokeAttributes attrs ->
                        { settings | connectorStrokeAttributes = attrs }

                    DragAndDrop isEnabled ->
                        { settings | isDragAndDropEnabled = isEnabled }

                    PlaceholderLeaves show ->
                        { settings | showPlaceholderLeaves = show }

                    ThrottleMouseMoves time ->
                        { settings | throttleMouseMoves = Just time }

                    CanDeactivate canDeactivate ->
                        { settings | canDeactivate = canDeactivate }
                )
