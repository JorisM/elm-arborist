module Styles exposing (..)

{-| Program styling
-}


blue : String
blue =
    "#075D84"


lightBlue : String
lightBlue =
    "#347A9A"


green : String
green =
    "#197753"


orange : String
orange =
    "#F18F01"


gray : String
gray =
    "#828481"


faintGray : String
faintGray =
    "#D1D7D4"


black : String
black =
    "#090B09"


raw : String
raw =
    """
* {
  -webkit-font-smoothing: antialiased;
  box-sizing: border-box;
  font-family: 'PT Sans', sans-serif;
}

body {
  background-color: #D3DBDC;
  padding: 30px;
}

h1 {
  margin: 0;
}

p {
  margin: 6px 0 0 0;
}

.intro {
  text-align: center;
  position: absolute;
  bottom: 20px;
  left: 20px;
  z-index: 100;
  padding: 20px;
  border: 1px solid rgba(0, 0, 0, 0.1);
}

.intro a {
  display: inline-block;
  margin: 0 6px;
}

.intro__icon {
  width: 60px;
  height: 60px;
  margin: -10px auto;
}

.intro__icon svg {
  width: 100%;
  height: 100%;
  fill: """ ++ green ++ """;
}

a {
  text-decoration: none;
  color: inherit;
  border-bottom: 1px solid currentColor;
  line-height: 1;
}

a:hover {
  color: """ ++ green ++ """;
}

input {
  outline: none;
  display: block;
  width: 100%;
  padding: 4px 8px;
  margin-top: 4px;
  border-radius: 4px;
  border: 1px solid """ ++ faintGray ++ """;
  transition: border-color 0.3s;
}

h1 {
  font-size: 1.5rem;
  font-weight: 400;
  margin: 0.5rem;
}

h2 {
  font-size: 0.75rem;
  font-weight: 400;
  margin: 0.5rem;
}

input:focus {
  box-shadow: 0 0 3px """ ++ green ++ """;
  border-color: """ ++ green ++ """;
}

label {
  color: """ ++ gray ++ """;
  display: block;
}

label:not(:first-of-type) {
  margin-top: 15px;
}

input,
label,
p,
button,
a {
  font-size: 0.875rem;
}

input,
label,
p {
  line-height: 1.6;
}

button {
  margin-top: 10px;
}

button:focus {
  outline: none;
  box-shadow: 0 0 3px """ ++ green ++ """;
}
"""


box : List ( String, String )
box =
    [ ( "background-color", "white" )
    , ( "margin", "auto" )
    ]


popup : List ( String, String )
popup =
    [ ( "width", "320px" )
    , ( "background-color", "white" )
    , ( "height", "240px" )
    , ( "border-top", "4px solid " ++ green )
    , ( "padding", "20px 20px 0 20px" )
    , ( "overflow", "auto" )
    , ( "position", "absolute" )
    , ( "transform", "translate3d(-50%, 50px, 0)" )
    , ( "box-shadow", "0 0 12px rgba(0, 0, 0, 0.25)" )
    ]


nodeContainer : List ( String, String )
nodeContainer =
    [ ( "width", "100%" )
    , ( "height", "45px" )
    , ( "font-size", "0.875rem" )
    , ( "padding", "4px 20px" )
    , ( "box-sizing", "border-box" )
    , ( "padding", "0 12px" )
    , ( "display", "flex" )
    , ( "align-items", "center" )
    , ( "justify-content", "center" )
    ]


text : List ( String, String )
text =
    [ ( "margin", "0" )
    , ( "font-size", "0.875rem" )
    , ( "line-height", "1.2" )
    , ( "text-align", "center" )
    ]


button : List ( String, String )
button =
    [ ( "background-color", green )
    , ( "border", "0" )
    , ( "padding", "6px 12px" )
    , ( "margin", "20px auto" )
    , ( "color", "#FFFFFF" )
    ]


bubble : List ( String, String )
bubble =
    [ ( "position", "absolute" )
    , ( "box-sizing", "border-box" )
    , ( "width", "fit-content" )
    , ( "min-width", "48px" )
    , ( "height", "28px" )
    , ( "border-radius", "14px" )
    , ( "border", "2px solid #E2E2E2" )
    , ( "background-color", "#FFF" )
    , ( "font-size", "0.75rem" )
    , ( "padding", "0 12px" )
    , ( "color", "black" )
    , ( "display", "flex" )
    , ( "align-items", "center" )
    , ( "justify-content", "center" )
    , ( "top", "-46px" )
    , ( "left", "50%" )
    , ( "transform", "translateX(-50%)" )
    , ( "z-index", "200" )
    ]
