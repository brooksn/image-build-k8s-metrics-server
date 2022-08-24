#!/bin/sh

make ORG=bcibase TAG="v0.5.2-build20220107" BUILD_META="-build20220107" image-build

make ORG=bcibase TAG="v0.5.0-build20211119" BUILD_META="-build20211119" image-build
