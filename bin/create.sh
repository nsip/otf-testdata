#!/bin/bash

set -euC

# Where do ou check out your NSIP code
export GITHUB_HOME=${GITHUB_HOME:="~/github"}
if [ ! -d "$GITHUB_HOME/otf-testdata" ]; then
    echo "Can't find otf-testdata in $GITHUB_HOME"
    exit 1
fi

# EXPERIMENTAL !
# Working area - currently only shared with reader
#
export PDM_ROOT=./data/otfdata

mkdir -p $PDM_ROOT
mkdir -p $PDM_ROOT/{in/{brightpath,lpofa,maps/{align,level},maths-pathway,spa},audit/{align,level},nss}

cp ./pdm_testdata/maps/alignmentMaps/nlpLinks.csv  $PDM_ROOT/in/maps/align
cp ./pdm_testdata/maps/alignmentMaps/providerItems.csv  $PDM_ROOT/in/maps/align
cp ./pdm_testdata/maps/levelMaps/scaleMap.csv  $PDM_ROOT/in/maps/level
cp ./pdm_testdata/maps/levelMaps/scoresMap.csv  $PDM_ROOT/in/maps/level
