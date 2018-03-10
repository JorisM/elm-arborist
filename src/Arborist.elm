module Arborist
    exposing
        ( Model
        , Msg
        , subscriptions
        , init
        , initWith
        , applySettings
        , resize
        , update
        , NodeView
        , view
        , tree
        , activeNode
        , activeNodeWithContext
        , setActiveNode
        , deleteActiveNode
        )

{-| Drag-and-drop interface to edit, dissect and-rearrange tree structures with arbitrary data sitting in their nodes. Structured as a TEA component defining its own init, update and view, `elm-arborist` allows you to easily initialize a tree editor, keep its state in an opaque model, and access the [edited result at any time](#tree).


# Module setup

@docs Model, Msg, init, initWith, update, NodeView, view, subscriptions


# Configuration

@docs applySettings, resize


# Tree getters and modifiers

@docs tree, activeNode, activeNodeWithContext, setActiveNode, deleteActiveNode

-}

import AnimationFrame
import Arborist.Context as Context
import Dict
import Html exposing (Html, Attribute, node, div, text, p, h1, h3, label, input, button)
import Html.Keyed
import Html.Attributes exposing (style, value)
import Html.Events exposing (onClick)
import Html.Events exposing (onInput, on, onWithOptions)
import Json.Decode as Decode
import Svg exposing (svg, line)
import Svg.Attributes exposing (width, height, viewBox, x1, x2, y1, y2, stroke, strokeWidth)
import Arborist.Tree
import Data.ComputedTree as ComputedTree
import Data.Settings as Settings exposing (Setting)
import Messages
import Drag exposing (Drag)
import Utils
import Utils.Tree as Tree exposing (TreeNodePath)
import Views.NodeConnectors
import Views.Styles as Styles


type ActiveNode
    = None
    | ExistingNode TreeNodePath
    | NewNode TreeNodePath


type alias NodeGeometry =
    { center : ( Float, Float )
    , childCenters : List ( Float, Float )
    }


{-| Opaque type for the editor's model, dependent on a node type variable. You can only use this for type annotation - to initialize a new model, see [init](#init).
-}
type Model node
    = Model
        { settings : Settings.Settings
        , computedTree : ComputedTree.ComputedTree node
        , prevComputedTree : ComputedTree.ComputedTree node
        , active : Maybe TreeNodePath
        , hovered : Maybe TreeNodePath
        , isReceivingAnimationFrames : Bool
        , focus : Maybe TreeNodePath
        , drag : Drag (Maybe TreeNodePath)
        , displayRoot : Maybe TreeNodePath
        , panOffset : ( Float, Float )
        , targetPanOffset : Maybe ( Float, Float )
        }


defaultSettings : Settings.Settings
defaultSettings =
    { nodeWidth = 120
    , nodeHeight = 36
    , canvasWidth = 600
    , canvasHeight = 480
    , level = 80
    , gutter = 20
    , centerOffset = ( 0, 0 )
    , connectorStrokeAttributes = []
    , isDragAndDropEnabled = True
    , showPlaceholderLeaves = True
    }


{-| Initialize model from a [tree](Tree).
-}
init : Arborist.Tree.Tree node -> Model node
init =
    initWith []


{-| Initialize model from a [tree](Tree), using a list of [settings](Settings).
-}
initWith : List Setting -> Arborist.Tree.Tree node -> Model node
initWith settings tree =
    let
        settings_ =
            Settings.apply settings defaultSettings

        computedTree =
            ComputedTree.init (settings_.showPlaceholderLeaves) tree
    in
        Model
            { settings = settings_
            , computedTree = computedTree
            , prevComputedTree = computedTree
            , active = Nothing
            , hovered = Nothing
            , isReceivingAnimationFrames = False
            , focus = Nothing
            , drag = Drag.init
            , displayRoot = Nothing
            , panOffset = ( 0, 0 )
            , targetPanOffset = Nothing
            }


{-| Apply a new list of settings to the model.
-}
applySettings : List Setting -> Model node -> Model node
applySettings settings (Model model) =
    Model
        { model
            | settings = Settings.apply settings model.settings
        }


{-| Resize the canvas by passing a new width and a new height. Note that you can reproduce this using [applySettings](#applySettings) as follows:

    resize 600 400 arborist == applySettings [ Settings.canvasWidth 600, Settings.canvasHeight 400 ] arborist

-}
resize : Int -> Int -> Model node -> Model node
resize width height =
    applySettings
        [ Settings.CanvasWidth width
        , Settings.CanvasHeight height
        ]


{-| DEPRECATED, see [activeNodeWithContext](#activeNodeWithContext). Returns the current active node as a tuple of `Maybe node` (as the node maybe a placeholder for a new node), as well as its position on the screen. This is the older, less detailed version of [activeNodeWithContext](#activeNodeWithContext).
-}
activeNode : Model node -> Maybe ( Maybe node, ( Float, Float ) )
activeNode model =
    activeNodeWithContext model
        |> Maybe.map (\( node, { position, context } ) -> ( node, position ))


{-| Returns the current active node as a tuple of `Maybe node` (as the node maybe a placeholder for a new node), as well as some contextual information as a two-field record:

  - `position : ( Float, Float )`: the node's position on the canvas (useful for rendering an edit pop-up).
  - `context`: view context, identical to the one provided in [NodeView](#NodeView).

-}
activeNodeWithContext : Model node -> Maybe ( Maybe node, { position : ( Float, Float ), context : Context.Context node } )
activeNodeWithContext (Model model) =
    model.active
        |> Maybe.map
            (\active ->
                let
                    treeLayout =
                        ComputedTree.layout model.computedTree

                    geo =
                        nodeGeometry model.settings active treeLayout
                            |> Maybe.map .center
                            |> Maybe.withDefault ( 0, 0 )

                    dragOffset =
                        Drag.state model.drag
                            |> Maybe.map Tuple.second
                            |> Maybe.withDefault ( 0, 0 )
                in
                    ( ComputedTree.item active model.computedTree
                    , { position =
                            [ geo
                            , model.panOffset
                            , dragOffset
                            ]
                                |> List.foldl Utils.addFloatTuples ( 0, 0 )
                      , context = viewContext (Model model) active
                      }
                    )
            )


{-| Sets a new node at the active position. This may be adding a completely new node from scratch (in case the current node is a placeholder), or modifying an existing one. Typically, the modification is based off an original value provided by the [activeNodeWithContext](#activeNodeWithContext) method.
-}
setActiveNode : node -> Model node -> Model node
setActiveNode newNode (Model model) =
    let
        tree =
            ComputedTree.tree model.computedTree

        flat =
            ComputedTree.flat model.computedTree

        newTree =
            -- Handle special case when the tree is completely empty
            -- and a new node is added at the root.
            if tree == Arborist.Tree.Empty && model.active == Just [] then
                Arborist.Tree.Node newNode []
            else
                model.active
                    |> Maybe.map
                        (\active ->
                            let
                                node =
                                    flat
                                        |> List.filter (\( path, _ ) -> active == path)
                                        |> List.head
                                        |> Maybe.map Tuple.second
                            in
                                case node of
                                    Just (Just node) ->
                                        Tree.update active newNode tree

                                    Just Nothing ->
                                        Tree.insert (List.take (List.length active - 1) active) (Just newNode) tree

                                    _ ->
                                        -- Impossible state
                                        tree
                        )
                    |> Maybe.withDefault tree
    in
        Model
            { model
                | computedTree = ComputedTree.init model.settings.showPlaceholderLeaves newTree
                , prevComputedTree = model.computedTree
            }


{-| Delete the active node from a tree, including all of its children. If a placeholder is active, this method does nothing.
-}
deleteActiveNode : Model node -> Model node
deleteActiveNode (Model model) =
    Model
        { model
            | computedTree =
                model.active
                    |> Maybe.map (\active -> Tree.delete active (ComputedTree.tree model.computedTree) |> ComputedTree.init model.settings.showPlaceholderLeaves)
                    |> Maybe.withDefault model.computedTree
            , prevComputedTree = model.computedTree
        }


{-| Subscriptions responsible for obtaining animation frames used to smoothly center an activated tree node. Using these subscriptions is completely optional - if they aren't wired up in your app, the editor will simply jump to the activated node without an animation. We recommend adding these subscriptions as you familiarize yourself with the package, as it is a significant user experience improvement.
-}
subscriptions : Model node -> Sub Msg
subscriptions (Model model) =
    if model.isReceivingAnimationFrames && model.targetPanOffset == Nothing then
        Sub.none
    else
        AnimationFrame.times Messages.AnimationFrameTick


{-| Access the current state of the tree through this getter (returns structure defined in the `Arborist.Tree` module). The result reflects all changes since it was [initialized](#init).
-}
tree : Model node -> Arborist.Tree.Tree node
tree (Model { computedTree }) =
    ComputedTree.tree computedTree


{-| Message type annotation for the program. When wiring up the editor within a larger program, you will define a `ArboristMsg Arborist.Msg` message type, one that will trigger this package's [update](#update) function.
-}
type alias Msg =
    Messages.Msg


{-| Logger function added to `update` in let block to log mouse events.
-}
logForDragDebug : Msg -> Model node -> String
logForDragDebug msg (Model model) =
    case msg of
        Messages.NodeMouseDown _ _ _ _ ->
            Debug.log "node-mouse-down" ""

        Messages.NodeMouseUp _ _ ->
            Debug.log "node-mouse-up" ""

        Messages.NodeMouseEnter _ ->
            Debug.log "node-mouse-enter" ""

        Messages.NodeMouseLeave _ ->
            Debug.log "node-mouse-leave" ""

        Messages.CanvasMouseDown _ _ ->
            Debug.log "canvas-mouse-down" ""

        Messages.CanvasMouseUp _ _ ->
            Debug.log "canvas-mouse-up" ""

        _ ->
            ""


{-| Update function handling changes in the model.
-}
update : Msg -> Model node -> Model node
update msg (Model model) =
    case msg of
        Messages.AnimationFrameTick time ->
            Model
                { model
                    | isReceivingAnimationFrames = True
                    , panOffset =
                        model.targetPanOffset
                            |> Maybe.map
                                (\( targetX, targetY ) ->
                                    let
                                        ( x, y ) =
                                            model.panOffset

                                        d =
                                            ((targetX - x) ^ 2 + (targetY - y) ^ 2) ^ 0.5

                                        dx =
                                            if (targetX == x) then
                                                0
                                            else
                                                (d / 10) * (targetX - x) / d

                                        dy =
                                            if (targetY == y) then
                                                0
                                            else
                                                (d / 10) * (targetY - y) / d
                                    in
                                        ( x + dx, y + dy )
                                )
                            |> Maybe.withDefault model.panOffset
                    , targetPanOffset =
                        model.targetPanOffset
                            |> Maybe.andThen
                                (\( targetX, targetY ) ->
                                    let
                                        ( x, y ) =
                                            model.panOffset
                                    in
                                        if abs (targetX - x) + abs (targetY - y) < 5 then
                                            Nothing
                                        else
                                            Just ( targetX, targetY )
                                )
                }

        Messages.NodeMouseDown isPlaceholder path x y ->
            Model
                { model
                    | drag =
                        (if isPlaceholder || not model.settings.isDragAndDropEnabled then
                            Drag.init
                         else
                            Drag.start (Just path) x y
                        )
                    , active =
                        if isPlaceholder || not model.settings.isDragAndDropEnabled then
                            Just path
                        else
                            Nothing
                }

        Messages.NodeMouseUp x y ->
            let
                isPlaceholder =
                    (activeNode (Model model) |> Maybe.map Tuple.first)
                        == (Just Nothing)

                active_ =
                    if isPlaceholder || not model.settings.isDragAndDropEnabled then
                        model.active
                    else
                        Drag.state model.drag
                            |> Maybe.andThen
                                (\( path, ( offsetX, offsetY ) ) ->
                                    case path of
                                        Just path ->
                                            -- If the node was dragged far enough already, it is not activated
                                            -- This case also protects from reading a slightly sloppy click as a drag
                                            if (abs offsetX + abs offsetY > 20) then
                                                Nothing
                                            else
                                                Just path

                                        Nothing ->
                                            Nothing
                                )

                flat =
                    ComputedTree.flat model.computedTree

                layout =
                    ComputedTree.layout model.computedTree

                tree =
                    ComputedTree.tree model.computedTree

                newPanOffset =
                    active_
                        |> Maybe.andThen
                            (\active_ ->
                                nodeGeometry model.settings active_ layout
                                    |> Maybe.map .center
                                    |> Maybe.map
                                        (\( cx, cy ) ->
                                            [ model.settings.centerOffset
                                            , ( model.settings.canvasWidth / 2
                                              , model.settings.canvasHeight / 2
                                              )
                                            , ( -cx, -model.settings.nodeHeight / 2 - cy )
                                            ]
                                                |> List.foldl Utils.addFloatTuples ( 0, 0 )
                                        )
                            )

                newTree =
                    Drag.state model.drag
                        |> Maybe.map
                            (\( path, dragOffset ) ->
                                path
                                    |> Maybe.map
                                        (\path ->
                                            getDropTarget model.settings path dragOffset model.computedTree
                                                |> Maybe.map
                                                    (\dropTargetPath ->
                                                        flat
                                                            |> List.filter (\( path, node ) -> path == dropTargetPath)
                                                            |> List.head
                                                            |> Maybe.andThen
                                                                (\( path, node ) ->
                                                                    case node of
                                                                        Just node ->
                                                                            Just ( path, node )

                                                                        Nothing ->
                                                                            Nothing
                                                                )
                                                            |> Maybe.map (\_ -> Tree.swap path dropTargetPath tree)
                                                            |> Maybe.withDefault
                                                                -- If the drop target is a placeholder, first add an Empty node in the original tree
                                                                -- so the swap method actually finds a node.
                                                                (Tree.insert (List.take (List.length dropTargetPath - 1) dropTargetPath) Nothing tree
                                                                    |> Tree.swap path dropTargetPath
                                                                    |> Tree.removeEmpties
                                                                )
                                                    )
                                                |> Maybe.withDefault tree
                                        )
                                    |> Maybe.withDefault tree
                            )
                        |> Maybe.withDefault tree
            in
                Model
                    { model
                        | drag =
                            Drag.init
                        , computedTree = ComputedTree.init model.settings.showPlaceholderLeaves newTree
                        , prevComputedTree = model.computedTree

                        -- If the client wired up the subscriptions, set the target pan offset to trigger the animation.
                        , targetPanOffset =
                            if model.isReceivingAnimationFrames then
                                newPanOffset
                            else
                                Nothing

                        -- Otherwise, center the view directly
                        , panOffset =
                            if model.isReceivingAnimationFrames then
                                model.panOffset
                            else
                                newPanOffset |> Maybe.withDefault model.panOffset
                        , active = active_
                    }

        Messages.NodeMouseEnter path ->
            Model
                { model
                    | hovered =
                        Just path
                }

        Messages.NodeMouseLeave path ->
            Model
                { model
                    | hovered =
                        if model.hovered == Just path then
                            Nothing
                        else
                            model.hovered
                }

        Messages.CanvasMouseMove xm ym ->
            Model
                { model
                    | drag =
                        Drag.move xm ym model.drag
                }

        Messages.CanvasMouseDown x y ->
            Model
                { model
                    | drag = Drag.start Nothing x y
                }

        Messages.CanvasMouseUp x y ->
            Model
                { model
                    | drag = Drag.init
                    , panOffset =
                        Drag.state model.drag
                            |> Maybe.map
                                (\( draggedNode, offset ) ->
                                    let
                                        ( panOffsetX, panOffsetY ) =
                                            model.panOffset

                                        ( offsetX, offsetY ) =
                                            if draggedNode == Nothing then
                                                offset
                                            else
                                                ( 0, 0 )
                                    in
                                        ( panOffsetX + offsetX, panOffsetY + offsetY )
                                )
                            |> Maybe.withDefault model.panOffset
                    , active =
                        Drag.state model.drag
                            |> Maybe.map
                                (\( path, ( x, y ) ) ->
                                    if (abs x + abs y) < 20 then
                                        Nothing
                                    else
                                        model.active
                                )
                            |> Maybe.withDefault Nothing
                }

        Messages.CanvasMouseLeave ->
            Model { model | drag = Drag.init }

        Messages.NoOp ->
            Model model


getDropTarget : Settings.Settings -> TreeNodePath -> ( Float, Float ) -> ComputedTree.ComputedTree node -> Maybe TreeNodePath
getDropTarget settings path ( dragX, dragY ) computedTree =
    let
        flat =
            ComputedTree.flat computedTree

        layout =
            ComputedTree.layout computedTree

        ( x0, y0 ) =
            nodeGeometry settings path layout
                |> Maybe.map .center
                |> Maybe.withDefault ( 0, 0 )

        ( x, y ) =
            ( x0 + dragX
            , y0 + dragY
            )
    in
        flat
            |> List.filterMap
                (\( path_, _ ) ->
                    let
                        ( xo, yo ) =
                            nodeGeometry settings path_ layout
                                |> Maybe.map .center
                                |> Maybe.withDefault ( 0, 0 )

                        dx =
                            abs (x - xo)

                        dy =
                            abs (y - yo)
                    in
                        if
                            (List.all identity
                                [ not (Utils.startsWith path path_)
                                , not (Utils.startsWith path_ path)
                                , dx < settings.nodeWidth
                                , dy < settings.nodeHeight
                                ]
                            )
                        then
                            Just ( path_, dx + dy )
                        else
                            Nothing
                )
            |> List.sortWith
                (\( _, d1 ) ( _, d2 ) ->
                    if d1 > d2 then
                        GT
                    else if d1 == d2 then
                        EQ
                    else
                        LT
                )
            |> List.head
            |> Maybe.map Tuple.first


nodeGeometry : Settings.Settings -> List Int -> Tree.Layout -> Maybe NodeGeometry
nodeGeometry settings path layout =
    layout
        |> Dict.get path
        |> Maybe.map
            (\{ center, childCenters } ->
                let
                    ( centerX, centerY ) =
                        center
                in
                    { center =
                        ( settings.canvasWidth / 2 + centerX * (settings.nodeWidth + settings.gutter)
                        , settings.canvasHeight * 0.1 + centerY * (settings.nodeHeight + settings.level)
                        )
                    , childCenters =
                        List.map
                            (\center ->
                                ( settings.canvasWidth / 2 + center * (settings.nodeWidth + settings.gutter)
                                , settings.canvasHeight * 0.1 + (centerY + 1) * (settings.nodeHeight + settings.level)
                                )
                            )
                            childCenters
                    }
            )


{-| View function for an individual node, depending on its [context](Context), and its value. This value is expressed as a maybe because the node may contain an `insert new node`-type placeholder.
-}
type alias NodeView node =
    Context.Context node -> Maybe node -> Html Msg


viewContext : Model node -> List Int -> Context.Context node
viewContext (Model model) path =
    let
        flatTree =
            ComputedTree.flat model.computedTree

        modelIsDragging =
            Drag.state model.drag /= Nothing

        isDropTarget =
            if modelIsDragging then
                Drag.state model.drag
                    |> Maybe.map
                        (\( draggedPath, offset ) ->
                            case draggedPath of
                                Just draggedPath ->
                                    getDropTarget model.settings draggedPath offset model.computedTree
                                        |> Maybe.map (\dropTargetPath -> dropTargetPath == path)
                                        |> Maybe.withDefault False

                                Nothing ->
                                    False
                        )
                    |> Maybe.withDefault False
            else
                False

        nodeViewContext =
            { parent =
                flatTree
                    |> List.filterMap
                        (\( path_, node ) ->
                            if path_ == List.take (List.length path - 1) path then
                                node
                            else
                                Nothing
                        )
                    |> List.head
            , siblings =
                flatTree
                    |> List.filterMap
                        (\( path_, node ) ->
                            node
                                |> Maybe.andThen
                                    (\node ->
                                        if path /= path_ && List.length path == List.length path_ && List.take (List.length path_ - 1) path_ == List.take (List.length path - 1) path then
                                            Just node
                                        else
                                            Nothing
                                    )
                        )
            , children =
                flatTree
                    |> List.filterMap
                        (\( path_, node ) ->
                            node
                                |> Maybe.andThen
                                    (\node ->
                                        if List.length path_ == List.length path + 1 && List.take (List.length path) path_ == path then
                                            Just node
                                        else
                                            Nothing
                                    )
                        )
            , state =
                if (model.active == Just path) then
                    Context.Active
                else if isDropTarget then
                    Context.DropTarget
                else if (model.hovered == Just path) then
                    Context.Hovered
                else
                    Context.Normal
            }
    in
        nodeViewContext


{-| The editor's view function, taking the following arguments:

  - [NodeView](#NodeView): view function for an individual node.
  - a list of html attributes for the container element.
  - the editor's [model](#Model).

-}
view : NodeView node -> List (Attribute Msg) -> Model node -> Html Msg
view viewNode attrs (Model model) =
    let
        flatTree =
            ComputedTree.flat model.computedTree

        layout =
            ComputedTree.layout model.computedTree

        nodeBaseStyle =
            Styles.nodeBase model.settings

        coordStyle =
            Styles.coordinate model.settings

        dragState =
            Drag.state model.drag

        isNodeDragging =
            dragState
                |> Maybe.map Tuple.first
                |> Maybe.map ((/=) Nothing)
                |> Maybe.withDefault False

        ( canvasDragOffset, isCanvasDragging ) =
            dragState
                |> Maybe.map
                    (\( path, offset ) ->
                        if path == Nothing then
                            ( offset, True )
                        else
                            ( ( 0, 0 ), False )
                    )
                |> Maybe.withDefault ( ( 0, 0 ), False )

        ( canvasTotalDragOffsetX, canvasTotalDragOffsetY ) =
            Utils.addFloatTuples canvasDragOffset model.panOffset
    in
        div
            ([ on "mousemove"
                (Decode.map2 Messages.CanvasMouseMove
                    (Decode.field "screenX" Decode.float)
                    (Decode.field "screenY" Decode.float)
                )
             , on "mousedown"
                (Decode.map2 Messages.CanvasMouseDown
                    (Decode.field "screenX" Decode.float)
                    (Decode.field "screenY" Decode.float)
                )
             , on "mouseup"
                (Decode.map2 Messages.CanvasMouseUp
                    (Decode.field "screenX" Decode.float)
                    (Decode.field "screenY" Decode.float)
                )
             , on "mouseleave" (Decode.succeed Messages.CanvasMouseLeave)
             , style
                [ ( "overflow", "hidden" )
                , ( "width", Utils.floatToPxString model.settings.canvasWidth )
                , ( "height", Utils.floatToPxString model.settings.canvasHeight )
                , ( "box-sizing", "border-box" )
                , ( "position", "relative" )
                , ( "cursor"
                  , if isCanvasDragging then
                        "move"
                    else
                        "auto"
                  )
                ]
             ]
                ++ attrs
            )
            [ Html.Keyed.node "div"
                [ style
                    [ ( "width", "100%" )
                    , ( "height", "100%" )
                    , ( "position", "relative" )
                    , ( "transform", "translate3d(" ++ (Utils.floatToPxString canvasTotalDragOffsetX) ++ ", " ++ (Utils.floatToPxString canvasTotalDragOffsetY) ++ ", 0)" )
                    ]
                ]
              <|
                (List.map
                    (\( path, node ) ->
                        nodeGeometry model.settings path layout
                            |> Maybe.map
                                (\{ center, childCenters } ->
                                    let
                                        ( x, y ) =
                                            center

                                        key =
                                            List.map toString path
                                                |> String.join "-"

                                        modelIsDragging =
                                            Drag.state model.drag /= Nothing

                                        ( isDragged, ( xDrag, yDrag ), draggedPath, isDropTarget ) =
                                            if modelIsDragging then
                                                dragState
                                                    |> Maybe.map
                                                        (\( draggedPath, offset ) ->
                                                            case draggedPath of
                                                                Just draggedPath ->
                                                                    let
                                                                        isDropTarget =
                                                                            getDropTarget model.settings draggedPath offset model.computedTree
                                                                                |> Maybe.map (\dropTargetPath -> dropTargetPath == path)
                                                                                |> Maybe.withDefault False
                                                                    in
                                                                        if Utils.startsWith draggedPath path then
                                                                            ( True, offset, Just draggedPath, isDropTarget )
                                                                        else
                                                                            ( False, ( 0, 0 ), Just draggedPath, isDropTarget )

                                                                Nothing ->
                                                                    ( False, ( 0, 0 ), Nothing, False )
                                                        )
                                                    |> Maybe.withDefault ( False, ( 0, 0 ), Nothing, False )
                                            else
                                                ( False, ( 0, 0 ), Nothing, False )

                                        xWithDrag =
                                            x + xDrag

                                        yWithDrag =
                                            y + yDrag

                                        nodeViewContext =
                                            viewContext (Model model) path
                                    in
                                        [ ( key
                                          , div
                                                [ style <|
                                                    nodeBaseStyle
                                                        ++ (coordStyle ( xWithDrag, yWithDrag ))
                                                        ++ (if isDragged then
                                                                [ ( "z-index", "100" )
                                                                , ( "cursor", "move" )
                                                                ]
                                                            else
                                                                []
                                                           )
                                                , Utils.onClickStopPropagation Messages.NoOp
                                                , onWithOptions "mousedown"
                                                    { stopPropagation = True
                                                    , preventDefault = False
                                                    }
                                                    (Decode.map2 (Messages.NodeMouseDown (node == Nothing) path)
                                                        (Decode.field "screenX" Decode.float)
                                                        (Decode.field "screenY" Decode.float)
                                                    )
                                                , onWithOptions "mouseup"
                                                    { stopPropagation = True
                                                    , preventDefault = False
                                                    }
                                                    (Decode.map2 Messages.NodeMouseUp
                                                        (Decode.field "screenX" Decode.float)
                                                        (Decode.field "screenY" Decode.float)
                                                    )
                                                , on "mouseenter" (Decode.succeed (Messages.NodeMouseEnter path))
                                                , on "mouseleave" (Decode.succeed (Messages.NodeMouseLeave path))
                                                ]
                                                [ viewNode nodeViewContext node
                                                ]
                                          )
                                        ]
                                            ++ (if isDragged then
                                                    [ ( key ++ "shadow"
                                                      , div
                                                            [ style <|
                                                                nodeBaseStyle
                                                                    ++ Styles.dragShadowNode
                                                                    ++ (coordStyle ( x, y ))
                                                            ]
                                                            []
                                                      )
                                                    ]
                                                        ++ (if node == Nothing then
                                                                []
                                                            else
                                                                [ ( key ++ "connector1", Views.NodeConnectors.view model.settings 0.3 ( 0, 0 ) center childCenters ) ]
                                                           )
                                                else
                                                    []
                                               )
                                            ++ (if node == Nothing then
                                                    []
                                                else
                                                    [ ( key ++ "connector2", Views.NodeConnectors.view model.settings 1.0 ( xDrag, yDrag ) center childCenters )
                                                    ]
                                               )
                                )
                            |> Maybe.withDefault []
                    )
                    flatTree
                    |> List.foldl (++) []
                )
            ]
