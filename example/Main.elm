module Main exposing (..)

import Task
import Json.Decode as Decode
import Html exposing (Html, div, node, h1, h2, h3, p, a, text, program, label, input, map, button)
import Html.Attributes exposing (class, style, value, type_, href)
import Html.Events exposing (onInput, onClick)
import Arborist
import Arborist.Tree exposing (..)
import Arborist.Config exposing (NodeState(..))
import Styles
import Window exposing (size, resizes)


{-| Configure Arborist
-}
arboristConfig : Arborist.Config.Config Item
arboristConfig =
    { view =
        (\context item ->
            let
                _ =
                    ( context, item ) |> Debug.log "c"
            in
                item
                    |> Maybe.map
                        (\item ->
                            div
                                [ style <|
                                    Styles.nodeContainer
                                        ++ [ ( "background-color"
                                             , case context.state of
                                                Active ->
                                                    Styles.green

                                                Hovered ->
                                                    Styles.lightBlue

                                                DropTarget ->
                                                    Styles.orange

                                                Normal ->
                                                    Styles.blue
                                             )
                                           , ( "color", "white" )
                                           ]
                                ]
                                [ div [] <|
                                    (if item.answer /= "" then
                                        [ p
                                            [ style <|
                                                Styles.bubble
                                                    ++ []
                                            ]
                                            [ text item.answer ]
                                        ]
                                     else
                                        []
                                    )
                                        ++ [ p [ style <| Styles.text ] [ text item.question ]
                                           ]
                                ]
                        )
                    |> Maybe.withDefault
                        (div
                            [ style <|
                                Styles.nodeContainer
                                    ++ (case context.state of
                                            Active ->
                                                [ ( "background-color", "#4DC433" )
                                                , ( "color", "white" )
                                                , ( "border", "0" )
                                                ]

                                            DropTarget ->
                                                [ ( "background-color", "#F18F01" )
                                                , ( "border", "0" )
                                                , ( "color", "white" )
                                                ]

                                            _ ->
                                                [ ( "background-color", "transparent" )
                                                , ( "border", "1px dashed #CECECE" )
                                                , ( "color", "black" )
                                                ]
                                       )
                            ]
                            [ p [ style <| Styles.text ] [ text "New child" ] ]
                        )
        )
    , layout =
        { nodeWidth = 200
        , nodeHeight = 60
        , canvasWidth = 1000
        , canvasHeight = 560
        , level = 120
        , gutter = 20
        }
    }



-- Program model


type alias Model =
    { arborist : Arborist.Model Item
    , newItem : Item
    , windowSize : Window.Size
    }



-- The Item data type held in the tree's nodes


type alias Item =
    { question : String
    , answer : String
    }


init =
    ( { arborist = Arborist.init tree
      , newItem = { question = "", answer = "" }
      , windowSize = { width = 0, height = 0 }
      }
    , Task.perform Resize Window.size
    )


setQuestion : String -> Item -> Item
setQuestion val item =
    { item | question = val }


setAnswer : String -> Item -> Item
setAnswer val item =
    { item | answer = val }


decoder : Decode.Decoder Item
decoder =
    Decode.map2 Item
        (Decode.field "question" Decode.string)
        (Decode.field "answer" Decode.string)



-- The starting tree itself.


tree : Tree Item
tree =
    Node { answer = "", question = "Do you like trees?" }
        [ Node { answer = "yes", question = "How much?" }
            [ Node { answer = "A lot!", question = "Where were you all my life?" } []
            ]
        , Node { answer = "No.", question = "Seriously?" }
            [ Node { answer = "Yes", question = "How about rollercoasters?" } []
            ]
        ]



-- Msg


type Msg
    = ArboristMsg (Arborist.Msg Item)
    | EditNewItemQuestion String
    | EditNewItemAnswer String
    | SetActive Item
    | DeleteActive
    | Resize Window.Size



-- Update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ArboristMsg arboristMsg ->
            ( { model | arborist = Arborist.update arboristConfig arboristMsg model.arborist }
            , Cmd.none
            )

        SetActive newItem ->
            ( { model | arborist = Arborist.setActiveNode newItem model.arborist }
            , Cmd.none
            )

        DeleteActive ->
            ( { model | arborist = Arborist.deleteActiveNode model.arborist }
            , Cmd.none
            )

        EditNewItemQuestion val ->
            ( { model
                | newItem = setQuestion val model.newItem
              }
            , Cmd.none
            )

        EditNewItemAnswer val ->
            ( { model
                | newItem = setAnswer val model.newItem
              }
            , Cmd.none
            )

        Resize size ->
            ( { model | windowSize = size }
            , Cmd.none
            )



-- View


view : Model -> Html Msg
view model =
    div [] <|
        [ node "style" [] [ text Styles.raw ]
        , div [ class "intro" ]
            [ h1 [] [ text "elm-arborist" ]
            , p [] [ text "a 🌲 editing interface (", a [ href "https://github.com/peterszerzo/elm-arborist" ] [ text "GitHub" ], text ")" ]
            ]
        ]
            ++ [ -- For pop-up coordinates to work, include view in a container
                 div
                    [ style
                        [ ( "margin", "auto" )
                        , ( "width", "1000px" )
                        , ( "height", "560px" )
                        , ( "position", "relative" )
                        ]
                    ]
                 <|
                    [ Arborist.view arboristConfig [ style Styles.box ] model.arborist |> Html.map ArboristMsg ]
                        ++ (Arborist.activeNode arboristConfig model.arborist
                                |> Maybe.map
                                    (\( item, ( x, y ) ) ->
                                        [ div
                                            [ style <|
                                                Styles.popup
                                                    ++ [ ( "left", (toString x) ++ "px" )
                                                       , ( "top", (toString y) ++ "px" )
                                                       ]
                                            ]
                                            (case item of
                                                Just item ->
                                                    [ label []
                                                        [ text "Question"
                                                        , input [ value item.question, onInput (\val -> SetActive { item | question = val }) ] []
                                                        ]
                                                    , label []
                                                        [ text "Answer"
                                                        , input [ value item.answer, onInput (\val -> SetActive { item | answer = val }) ] []
                                                        ]
                                                    , button [ onClick DeleteActive ] [ text "Delete" ]
                                                    ]

                                                Nothing ->
                                                    [ label []
                                                        [ text "Question", input [ value model.newItem.question, onInput EditNewItemQuestion ] [] ]
                                                    , label []
                                                        [ text "Answer", input [ value model.newItem.answer, onInput EditNewItemAnswer ] [] ]
                                                    , button [ type_ "submit", onClick (SetActive model.newItem) ] [ text "Add node" ]
                                                    ]
                                            )
                                        ]
                                    )
                                |> Maybe.withDefault []
                           )
               ]



-- Entry point


main : Program Never Model Msg
main =
    program
        { init = init
        , update = update
        , view = view
        , subscriptions =
            (\model ->
                Sub.batch
                    [ Arborist.subscriptions model.arborist |> Sub.map ArboristMsg
                    , Window.resizes Resize
                    ]
            )
        }
