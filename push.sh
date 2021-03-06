#!/bin/bash
git commit -a -m "Distribution Build";
git push;

BUILT_PRODUCTS_DIR="$PWD/build/today"
PROJECT_NAME="Bigpond Menu Bar"


VERSION=$(defaults read "$BUILT_PRODUCTS_DIR/$PROJECT_NAME.app/Contents/Info" CFBundleVersion)
DOWNLOAD_BASE_URL="http://aantthony.github.com/BigPond-Usage-Meter/download"
ARCHIVE_FILENAME="$PROJECT_NAME $VERSION.zip"
DOWNLOAD_URL="$DOWNLOAD_BASE_URL/$ARCHIVE_FILENAME"
KEYCHAIN_PRIVKEY_NAME="Sparkle Private Key 1"

WD=$PWD
cd "$BUILT_PRODUCTS_DIR"
rm -f "$PROJECT_NAME"*.zip
ditto -ck --keepParent "$PROJECT_NAME.app" "$ARCHIVE_FILENAME"

SIZE=$(stat -f %z "$ARCHIVE_FILENAME")
PUBDATE=$(LC_TIME=en_US date +"%a, %d %b %G %T %z")
DATE_TEXT=$(LC_TIME=en_US date +"%G-%m-%d")
VERSION_CODE=$(git rev-parse --short HEAD)
TFILE=${DATE_TEXT}-${VERSION_CODE}.textile
SIGNATURE=$(
	openssl dgst -sha1 -binary < "$ARCHIVE_FILENAME" \
	| openssl dgst -dss1 -sign <(security find-generic-password -g -s "$KEYCHAIN_PRIVKEY_NAME" 2>&1 1>/dev/null | perl -pe '($_) = /"(.+)"/; s/\\012/\n/g' | perl -MXML::LibXML -e 'print XML::LibXML->new()->parse_file("-")->findvalue(q(//string[preceding-sibling::key[1] = "NOTE"]))') | openssl enc -base64
)

[ $SIGNATURE ] || { echo Unable to load signing private key with name "'$KEYCHAIN_PRIVKEY_NAME'" from keychain; false; }


cat - ../../releasenotes.textile > $TFILE <<EOF
---
layout: post
title: Version $VERSION
filesize: $SIZE
version: $VERSION
dsaSignature: $SIGNATURE
file: $DOWNLOAD_URL
pubdate: $PUBDATE
---

EOF
echo "No release notes given." >../../releasenotes.textile

git stash
mkdir -p ../../_posts
mkdir -p ../../download
cp "$TFILE" ../../_posts
cp "$ARCHIVE_FILENAME" ../../download

cd ../../
branch=`git branch | grep '\*' | sed 's/\* *//'`
git checkout gh-pages
mkdir -p ./_posts
mkdir -p ./download
git add "_posts/$TFILE"
git add "download/${ARCHIVE_FILENAME}"
git commit -m "publish ${VERSION}"
git push
git checkout $branch
git stash pop