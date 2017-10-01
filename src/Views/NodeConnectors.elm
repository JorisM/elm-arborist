module Views.NodeConnectors exposing (..)

import Html exposing (Html)
import Html.Attributes exposing (style)
import Svg exposing (svg, line)
import Svg.Attributes exposing (width, height, viewBox, x1, x2, y1, y2, stroke, strokeWidth, strokeLinecap, strokeLinejoin)
import Views.Styles as Styles


strokeColor : String
strokeColor =
    "#E2E2E2"


pad : Float
pad =
    4


strokeWeight : Int
strokeWeight =
    4


toCoord : Float -> String
toCoord =
    floor >> toString


view : { width : Float, height : Float, level : Float, gutter : Float } -> ( Float, Float ) -> ( Float, Float ) -> List ( Float, Float ) -> Html msg
view layout ( dragX, dragY ) center childCenters =
    let
        strokeAttrs =
            [ stroke strokeColor
            , strokeWidth (toString strokeWeight)
            , strokeLinecap "round"
            , strokeLinejoin "round"
            ]

        pts =
            [ center ] ++ childCenters

        minX =
            pts |> List.map Tuple.first |> List.foldl min 100000

        minY =
            pts |> List.map Tuple.second |> List.foldl min 100000

        maxX =
            pts |> List.map Tuple.first |> List.foldl max -100000

        maxY =
            pts |> List.map Tuple.second |> List.foldl max -100000

        w_ =
            maxX - minX

        w =
            if w_ < 8 then
                8
            else
                w_

        h_ =
            maxY - minY - layout.height

        h =
            if h_ < 0 then
                (layout.level)
            else
                h_

        relCenter =
            ( Tuple.first center - minX, Tuple.second center - minY )

        relChildren =
            List.map (\( x, y ) -> ( x - minX, y - minY )) childCenters
    in
        svg
            [ width (toString (w + 4))
            , height (toString h)
            , viewBox <|
                (if List.length childCenters == 0 then
                    "-4 0 4 " ++ (toString h)
                 else
                    "-2 0 " ++ (toString (w + 4)) ++ " " ++ (toString h)
                )
            , style <|
                [ ( "position", "absolute" ) ]
                    ++ (Styles.coordinate layout.width (minX + (layout.width / 2) + dragX) (minY + layout.height + dragY))
            ]
        <|
            (if List.length childCenters == 0 then
                []
             else
                [ line
                    ([ x1 <| toCoord (Tuple.first relCenter)
                     , y1 <| toCoord pad
                     , x2 <| toCoord (Tuple.first relCenter)
                     , y2 <| toCoord (h / 2)
                     ]
                        ++ strokeAttrs
                    )
                    []
                ]
                    ++ (List.map
                            (\( x, y ) ->
                                line
                                    ([ x1 <| toCoord (x)
                                     , y1 <| toCoord (h / 2)
                                     , x2 <| toCoord (x)
                                     , y2 <| toCoord (h - pad)
                                     ]
                                        ++ strokeAttrs
                                    )
                                    []
                            )
                            relChildren
                       )
                    ++ (if List.length childCenters > 1 then
                            [ line
                                ([ x1 <| toCoord 1
                                 , y1 <| toCoord (h / 2)
                                 , x2 <| toCoord (w - 1)
                                 , y2 <| toCoord (h / 2)
                                 ]
                                    ++ strokeAttrs
                                )
                                []
                            ]
                        else
                            []
                       )
            )
