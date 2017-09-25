module Treditor
    exposing
        ( Model
        , Msg(SetActive, DeleteActive)
        , init
        , update
        , view
        , tree
        , isNew
        , setNew
        , active
        )

import Dict
import Json.Decode as Decode
import Html exposing (Html, Attribute, node, div, text, p, h1, h3, label, input, button)
import Html.Attributes exposing (style, value)
import Html.Events exposing (onInput, on, onWithOptions)
import Svg exposing (svg, line)
import Svg.Attributes exposing (width, height, viewBox, x1, x2, y1, y2, stroke, strokeWidth)
import Html.Events exposing (onClick)
import Data.Tree as Tree
import MultiDrag as MultiDrag
import Utils
import Views.Styles as Styles
import Views.NodeConnectors
import Treditor.Config as Config


-- Types


type alias NodeId =
    String


type alias NodePath =
    List Int


type alias TreeContext item =
    { tree : Tree.Tree item
    , active : Maybe NodePath
    , isDragging : Bool
    , focus : Maybe NodePath
    , new : Maybe NodePath
    , dropTarget : Maybe NodePath
    , dragState : Maybe ( NodePath, ( Float, Float ) )
    }


type alias TreeCache item =
    { withPlaceholders : Tree.Tree item
    , flat : List ( NodePath, Maybe item )
    , layout : Tree.Layout
    }


cacheTree : Tree.Tree item -> TreeCache item
cacheTree tree =
    let
        withPlaceholders =
            Tree.addTrailingEmpties tree

        flat =
            Tree.flatten withPlaceholders

        layout =
            withPlaceholders
                |> Tree.analyze
                |> Tree.layout
    in
        { withPlaceholders = withPlaceholders
        , flat = flat
        , layout = layout
        }



-- Model


type Model item
    = Model
        { tree : Tree.Tree item
        , treeCache : TreeCache item
        , new : Maybe NodePath
        , active : Maybe NodePath
        , isDragging : Bool
        , focus : Maybe NodePath
        , drag : MultiDrag.Drag NodePath
        , displayRoot : Maybe NodePath
        }


init : Tree.Tree item -> Model item
init tree =
    Model
        { tree = tree
        , treeCache = cacheTree tree
        , active = Nothing
        , new = Nothing
        , isDragging = False
        , focus = Nothing
        , drag = (MultiDrag.init)
        , displayRoot = Nothing
        }


setTreeCache : Model item -> Model item
setTreeCache (Model model) =
    Model { model | treeCache = cacheTree model.tree }


active : Model item -> Maybe item
active (Model { active, tree }) =
    active
        |> Maybe.andThen
            (\active ->
                Tree.find active tree
                    |> Maybe.andThen
                        (\subtree ->
                            case subtree of
                                Tree.Empty ->
                                    Nothing

                                Tree.Node item children ->
                                    Just item
                        )
            )


setNew : item -> Model item -> Model item
setNew item (Model model) =
    Model
        { model
            | tree =
                model.new
                    |> Maybe.map
                        (\new ->
                            Tree.insert new item model.tree
                        )
                    |> Maybe.withDefault model.tree
        }
        |> setTreeCache


tree : Model item -> Tree.Tree item
tree (Model { tree }) =
    tree


isNew : Model item -> Bool
isNew (Model { new }) =
    new /= Nothing


getDropTarget : Config.Config item (Msg item) -> NodePath -> ( Float, Float ) -> TreeCache item -> Maybe NodePath
getDropTarget config path ( dragX, dragY ) treeCache =
    let
        { flat, layout } =
            treeCache

        ( x0, y0 ) =
            nodeGeometry config path layout
                |> Maybe.map .center
                |> Maybe.withDefault ( 0, 0 )

        ( x, y ) =
            ( x0 + dragX
            , y0 + dragY
            )
    in
        flat
            |> List.filter
                (\( path_, _ ) ->
                    let
                        ( xo, yo ) =
                            nodeGeometry config path_ layout
                                |> Maybe.map .center
                                |> Maybe.withDefault ( 0, 0 )
                    in
                        path /= path_ && (abs (x - xo) < config.layout.width) && (abs (y - yo) < config.layout.height)
                )
            |> List.filter (\( dropTargetPath, _ ) -> not (startsWith path dropTargetPath || startsWith dropTargetPath path))
            |> List.head
            |> Maybe.map Tuple.first



-- Msg


type Msg item
    = Deactivate
    | SetActive item
    | DeleteActive
    | SetNew NodePath
    | SetFocus (Maybe NodePath)
    | MouseMove Float Float
    | MouseDown Bool NodePath Float Float
    | MouseUp Float Float
    | NoOp



-- Update


update : Config.Config item (Msg item) -> Msg item -> Model item -> Model item
update config msg (Model model) =
    case msg of
        SetActive newItem ->
            Model
                { model
                    | tree =
                        model.active
                            |> Maybe.map (\active -> Tree.update active newItem model.tree)
                            |> Maybe.withDefault model.tree
                }
                |> setTreeCache

        DeleteActive ->
            Model
                { model
                    | tree =
                        model.active
                            |> Maybe.map (\active -> Tree.delete active model.tree)
                            |> Maybe.withDefault model.tree
                }
                |> setTreeCache

        SetFocus focus ->
            Model model

        SetNew nodePath ->
            Model
                { model
                    | new = Just nodePath
                    , active = Nothing
                }

        Deactivate ->
            Model { model | active = Nothing, new = Nothing }

        MouseDown isPlaceholder path x y ->
            Model
                { model
                    | drag =
                        MultiDrag.start path x y
                    , new =
                        if isPlaceholder then
                            Just (List.take (List.length path - 1) path)
                        else
                            Nothing
                    , active =
                        if isPlaceholder then
                            Nothing
                        else
                            Just path
                }

        MouseMove xm ym ->
            Model
                { model
                    | drag =
                        MultiDrag.move xm ym model.drag
                    , isDragging =
                        if MultiDrag.state model.drag /= Nothing then
                            True
                        else
                            False
                }

        MouseUp x y ->
            let
                newTree =
                    MultiDrag.state model.drag
                        |> Maybe.andThen
                            (\( path, dragOffset ) ->
                                getDropTarget config path dragOffset model.treeCache
                                    |> Maybe.map (\dropTargetPath -> Tree.swap path dropTargetPath model.tree)
                            )
                        |> Maybe.withDefault model.tree
            in
                Model
                    { model
                        | drag =
                            MultiDrag.init
                        , tree = newTree
                        , isDragging = False
                    }
                    |> setTreeCache

        NoOp ->
            Model model


type alias NodeGeometry =
    { center : ( Float, Float )
    , childCenters : List ( Float, Float )
    }


nodeGeometry : Config.Config item (Msg item) -> List Int -> Tree.Layout -> Maybe NodeGeometry
nodeGeometry config path layout =
    layout
        |> Dict.get path
        |> Maybe.map
            (\{ center, childCenters } ->
                let
                    ( centerX, centerY ) =
                        center
                in
                    { center =
                        ( centerX * (config.layout.width + config.layout.horizontalGap)
                        , centerY * (config.layout.height + config.layout.verticalGap)
                        )
                    , childCenters =
                        List.map
                            (\center ->
                                ( center * (config.layout.width + config.layout.horizontalGap)
                                , (centerY + 1) * (config.layout.height + config.layout.verticalGap)
                                )
                            )
                            childCenters
                    }
            )


startsWith : List a -> List a -> Bool
startsWith start list =
    List.take (List.length start) list == start


view : Config.Config item (Msg item) -> List (Attribute (Msg item)) -> Model item -> Html (Msg item)
view config attrs (Model model) =
    let
        tree =
            model.treeCache.withPlaceholders

        flatTree =
            model.treeCache.flat

        layout =
            model.treeCache.layout

        nodeBaseStyle =
            Styles.nodeBase config.layout.width config.layout.height

        coordStyle =
            Styles.coordinate config.layout.width
    in
        div
            ([ on "mousemove"
                (Decode.map2 MouseMove
                    (Decode.field "screenX" Decode.float)
                    (Decode.field "screenY" Decode.float)
                )
             , style [ ( "text-align", "center" ) ]
             , onClick Deactivate
             ]
                ++ attrs
            )
        <|
            (List.map
                (\( path, item ) ->
                    nodeGeometry config path layout
                        |> Maybe.map
                            (\{ center, childCenters } ->
                                let
                                    ( x, y ) =
                                        center

                                    dragState =
                                        MultiDrag.state model.drag

                                    ( isDragged, ( xDrag, yDrag ), draggedPath ) =
                                        if model.isDragging then
                                            dragState
                                                |> Maybe.map
                                                    (\( draggedPath, offset ) ->
                                                        if startsWith draggedPath path then
                                                            ( True, offset, Just draggedPath )
                                                        else
                                                            ( False, ( 0, 0 ), Just draggedPath )
                                                    )
                                                |> Maybe.withDefault ( False, ( 0, 0 ), Nothing )
                                        else
                                            ( False, ( 0, 0 ), Nothing )

                                    isDropTarget =
                                        dragState
                                            |> Maybe.map
                                                (\( draggedPath, offset ) ->
                                                    getDropTarget config draggedPath offset model.treeCache
                                                        |> Maybe.map (\dropTargetPath -> startsWith dropTargetPath path)
                                                        |> Maybe.withDefault False
                                                )
                                            |> Maybe.withDefault False

                                    isActive =
                                        model.active == Just path || isDragged

                                    xWithDrag =
                                        x + xDrag

                                    yWithDrag =
                                        y + yDrag

                                    itemViewContext =
                                        { parent = Nothing
                                        , siblings = []
                                        , position = ( x, y )
                                        , isActive = isActive
                                        , isDropTarget = isDropTarget
                                        }
                                in
                                    [ div
                                        [ style <|
                                            nodeBaseStyle
                                                ++ (coordStyle xWithDrag yWithDrag)
                                                ++ (if isDragged then
                                                        [ ( "z-index", "100" ) ]
                                                    else
                                                        []
                                                   )
                                        , Utils.onClickStopPropagation NoOp
                                        , onWithOptions "mousedown"
                                            { stopPropagation = True
                                            , preventDefault = False
                                            }
                                            (Decode.map2 (MouseDown (item == Nothing) path)
                                                (Decode.field "screenX" Decode.float)
                                                (Decode.field "screenY" Decode.float)
                                            )
                                        , onWithOptions "mouseup"
                                            { stopPropagation = True
                                            , preventDefault = False
                                            }
                                            (Decode.map2 MouseUp
                                                (Decode.field "screenX" Decode.float)
                                                (Decode.field "screenY" Decode.float)
                                            )
                                        ]
                                        [ item
                                            |> Maybe.map (config.view itemViewContext)
                                            |> Maybe.withDefault (config.placeholderView itemViewContext)
                                        ]
                                    ]
                                        ++ (if isDragged then
                                                [ p
                                                    [ style <|
                                                        nodeBaseStyle
                                                            ++ Styles.dragShadowNode
                                                            ++ (coordStyle x y)
                                                    ]
                                                    []
                                                ]
                                            else
                                                []
                                           )
                                        ++ [ Views.NodeConnectors.view config.layout ( xDrag, yDrag ) center childCenters
                                           ]
                            )
                        |> Maybe.withDefault []
                )
                flatTree
                |> List.foldl (++) []
            )
