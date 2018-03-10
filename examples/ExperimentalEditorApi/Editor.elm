module ExperimentalEditorApi.Editor exposing (..)

import Html exposing (Html, div)
import Html.Attributes exposing (style)
import Arborist
import Arborist.Settings as Settings
import Arborist.Tree as Tree
import ExperimentalEditorApi.Node as Node
import Window


type alias Data =
    Tree.Tree Node.Node


type alias State =
    { arborist : Arborist.Model Node.Node
    , newNode : Node.Node
    }


init : Tree.Tree Node.Node -> State
init startTree =
    { arborist = Arborist.initWith [ Settings.nodeWidth 80, Settings.nodeHeight 40 ] startTree
    , newNode = Node.placeholder
    }


subscriptions : Config msg -> Sub msg
subscriptions config =
    Arborist.subscriptions config.state.arborist
        |> Sub.map
            (\msg ->
                let
                    state =
                        config.state
                in
                    config.toMsg
                        { state | arborist = Arborist.update msg state.arborist }
                        config.data
            )


type alias Config msg =
    { data : Data
    , windowSize : Window.Size
    , state : State
    , toMsg : State -> Data -> msg
    }


view : Config msg -> Html msg
view config =
    div []
        [ Arborist.view
            (\_ _ ->
                div
                    [ style
                        [ ( "width", "80px" )
                        , ( "height", "40px" )
                        , ( "background-color", "#adadad" )
                        ]
                    ]
                    [ Html.text "a" ]
            )
            []
            config.state.arborist
            |> Html.map
                (\msg ->
                    let
                        state =
                            config.state

                        newArborist =
                            Arborist.update msg config.state.arborist
                    in
                        config.toMsg { state | arborist = newArborist } config.data
                )
        ]
