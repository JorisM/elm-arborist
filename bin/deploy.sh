function deploy() {
  git branch -D gh-pages
  git checkout --orphan gh-pages
  cp build/* .
  trash src examples tests
  git add .
  git commit -m "Deploy"
  git push -f origin gh-pages
}

function build() {
  rm -rf build
  mkdir -p build/Egg
  cd examples
  elm-make Main.elm --output=../build/elm.js
  cp index.html ../build
  elm-make Egg/Main.elm --output=../build/Egg/elm.js
  cp Egg/index.html ../build/Egg
  cp Egg/index.js ../build/Egg
}

build
deploy
