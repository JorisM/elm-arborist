rm -rf build
mkdir build
cd example
elm-make Main.elm --output=../build/index.html
surge ../build elm-arborist.peterszerzo.com
