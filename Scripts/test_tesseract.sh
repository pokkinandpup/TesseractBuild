#!/bin/zsh -f

thisAbsPath=${0:A}
scriptsDir=${thisAbsPath%/*}
TBE_PROJECTDIR=${scriptsDir%/Scripts}

source $TBE_PROJECTDIR/Scripts/set_env.sh || {
  echo "ERROR could not source $TBE_PROJECTDIR/Scripts/set_env.sh"
  exit 1
}

mkdir -p $TESSDATA_PREFIX

echo 'Checking for trained data language files...'

langfiles=(
  'chi_tra.traineddata'
  'chi_tra_vert.traineddata'
  'eng.traineddata'
  'jpn.traineddata'
  'jpn_vert.traineddata'
)

for langfile in $langfiles; do
  if [ -f $TESSDATA_PREFIX/$langfile ]; then
    echo " found ${TESSDATA_PREFIX/$TBE_PROJECTDIR/\$TBE_PROJECTDIR}/$langfile"
    continue
  fi

  print -n " downloading $langfile..."
  curl -L -f -s \
    https://github.com/tesseract-ocr/tessdata_best/raw/main/$langfile \
    --output $TESSDATA_PREFIX/$langfile \
    || { echo "Error: could not download https://github.com/tesseract-ocr/tessdata_best/raw/master/$langfile"; exit 1 }
  print 'done.'
done

strip_whitespace() {
  local filename=$1

  cat $filename | tr -d '\n' | tr -d '\f' | tr -d ' '
}

echo "Recognizing sample images with ${$(which tesseract)/$TBE_PROJECTDIR/\$TBE_PROJECTDIR}..."

ASSETSDIR=$TBE_PROJECTDIR/iOCR/Assets.xcassets
TESTDIR=tesseractTest

mkdir -p $TESTDIR; cd $TESTDIR || exit 1

test_image() {
  # Run tesseract command-line program on a number of sample/test images;
  #
  #   tesseract CL program should be in Root/bin, and Root/bin is
  #   added to $PATH in set_env.sh
  local testName=$1
  local image=$2
  local trainedDataName=$3
  local whtspcStrippedWant=$4

  print -n " testing $testName... "

  if ! [ -f $image ]; then
    echo "ERROR could not find image file $image"
    return
  fi

  if ! [ -f "$TESSDATA_PREFIX/$trainedDataName.traineddata" ]; then
    echo "ERROR could not find language file $TESSDATA_PREFIX/$trainedDataName.traineddata"
    return
  fi

  local tessOutFile=$trainedDataName

  # Clear any lingering state
  rm -f $tessOutFile.txt

  # These params will run OCR on $image and create $tessOutFile.txt (txt is default out-type)
  tesseract $image $tessOutFile -l $trainedDataName 2>/dev/null
  got=$(strip_whitespace $tessOutFile.txt)

  if [ $got = $whtspcStrippedWant ]; then
    print 'passed.'
  else
    print "*failed*: got '$got', want '$whtspcStrippedWant'"
  fi
}

vars=(
  'Japanese'
  $ASSETSDIR/japanese.imageset/test_hello_hori.png
  'jpn'
  'Hello,世界'
)

test_image $vars

vars=(
  'Japanese (vert)'
  $ASSETSDIR/japanese_vert.imageset/test_hello_vert.png
  'jpn_vert'
  'Hello,世界'
)

test_image $vars

vars=(
  'Chinese (trad, vert)'
  $ASSETSDIR/chinese_traditional_vert.imageset/cropped.png
  'chi_tra_vert'
  '哈哈我第一個到終點了!'
)

test_image $vars

vars=(
  'English'
  $ASSETSDIR/english_left_just_square.imageset/hexdreams.png
  'eng'
  "WelcometoHexdreamer'sdreamofasimple-to-followguideforaddingaC-API,andspecificallyTesseractOCR'sC-API,intoanXcodeprojectforuseinadreamiOSmanga-readerapp."
)

test_image $vars

cd ..; rm -rf $TESTDIR