rm -rf build
mkdir build
elm-make Main.elm --output=build/index.html
surge build treeditor.surge.sh
