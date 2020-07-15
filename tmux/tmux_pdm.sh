#!/bin/bash

set -euC


# 
# pre-tmux stuff, setting env vars etc.
# 

# 
# general working area for demo
# we'll drop files here
# watch audit outputs & run 
# nats server here
# 
export PDM_ROOT=~/otfdata 
# 
# now create demo input/audit/nats
# folder structure
mkdir -p $PDM_ROOT
mkdir -p $PDM_ROOT/{in/{brightpath,lpofa,maps/{align,level},maths-pathway,spa},audit/{align,level},nss}


att() {
    [ -n "${TMUX:-}" ] &&
        tmux switch-client -t '=otfpdm' ||
        tmux attach-session -t '=otfpdm'
}

if tmux has-session -t '=otfpdm' 2> /dev/null; then
    att
    exit 0
fi

# create the new master session
tmux new-session -d -s otfpdm

# start a nats server instance
tmux new-window -d -t '=otfpdm' -n nats -c $PDM_ROOT/nss 
tmux send-keys -t '=otfpdm:=nats' 'nats-streaming-server' Enter

# give the nats server time to come up
sleep 2

# start an n3 server
tmux new-window -d -t '=otfpdm' -n n3w -c ~/github/n3-web/server/n3w
tmux send-keys -t '=otfpdm:=n3w' 'rm -r ./contexts' Enter # remove any previous data
tmux send-keys -t '=otfpdm:=n3w' './n3w' Enter # start the server

# start the text classifier
tmux new-window -d -t '=otfpdm' -n txtclss -c ~/github/otf-classifier/cmd/otf-classifier
tmux send-keys -t '=otfpdm:=txtclss' './otf-classifier' Enter

# start the aligner
tmux new-window -d -t '=otfpdm' -n align -c ~/github/otf-align/cmd/otf-align
tmux send-keys -t '=otfpdm:=align' './otf-align --port=1324' Enter


# 
# start the inbound data readers
# 
# 
# for brightpath data
tmux new-window -d -t '=otfpdm' -n rdr_bp -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_bp' './otf-reader --folder=$PDM_ROOT/in/brightpath --config=./config/bp_config.json' Enter
# 
# for lpofa (xapi) literacy data
tmux new-window -d -t '=otfpdm' -n rdr_lpofa_lit -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_lpofa_lit' './otf-reader --folder=$PDM_ROOT/in/lpofa --config=./config/lpofa_literacy_config.json' Enter
# 
# for lpofa (xapi) numeracy data
tmux new-window -d -t '=otfpdm' -n rdr_lpofa_num -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_lpofa_num' './otf-reader --folder=$PDM_ROOT/in/lpofa --config=./config/lpofa_numeracy_config.json' Enter
# 
# for maths pathway data
tmux new-window -d -t '=otfpdm' -n rdr_mp -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_mp' './otf-reader --folder=$PDM_ROOT/in/maths-pathway --config=./config/mp_config.json' Enter
# 
# for sreams (SPA) mapped data
tmux new-window -d -t '=otfpdm' -n rdr_spa_mapped -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_spa_mapped' './otf-reader --folder=$PDM_ROOT/in/spa --config=./config/spa_mapped_config.json' Enter
# 
# for sreams (SPA) prescribed data
tmux new-window -d -t '=otfpdm' -n rdr_spa_prescribed -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_spa_prescribed' './otf-reader --folder=$PDM_ROOT/in/spa --config=./config/spa_prescribed_config.json' Enter
# 
# for alignment service data maps
tmux new-window -d -t '=otfpdm' -n rdr_alignment_maps -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_alignment_maps' './otf-reader --folder=$PDM_ROOT/in/maps/align --config=./config/alignMaps_config.json' Enter
# 
# for the levelling service data maps
tmux new-window -d -t '=otfpdm' -n rdr_level_maps -c ~/github/otf-reader/cmd/otf-reader
tmux send-keys -t '=otfpdm:=rdr_level_maps' './otf-reader --folder=$PDM_ROOT/in/maps/level --config=./config/levelMaps_config.json' Enter



# 
# start benthos workflows
# 
# 
# start the alignment data processing workflow
tmux new-window -d -t '=otfpdm' -n benthos_align -c ~/github/otf-align/cmd/benthos
tmux send-keys -t '=otfpdm:=benthos_align' './run_benthos_align_data.sh' Enter
# 
# start the levelling data processing workflow
tmux new-window -d -t '=otfpdm' -n benthos_level -c ~/github/otf-level/cmd/benthos
tmux send-keys -t '=otfpdm:=benthos_level' './run_benthos_level_data.sh' Enter
# 
# start the benthos alignment map publishing workflow
tmux new-window -d -t '=otfpdm' -n benthos_align_map_publish -c ~/github/otf-align/cmd/benthos
tmux send-keys -t '=otfpdm:=benthos_align_map_publish' './run_benthos_align_maps.sh' Enter
#
# start the benthos level map publishing workflow
tmux new-window -d -t '=otfpdm' -n benthos_level_map_publish -c ~/github/otf-level/cmd/benthos
tmux send-keys -t '=otfpdm:=benthos_level_map_publish' './run_benthos_level_maps.sh' Enter

# 
# send mapping data into the system
# so services are preconfigured 
# with some levelling / alignment maps
# 
# pause between sends as other sessions start at different rates
# eg. n3 may not fully be up by the time we get here
# 
sleep 5
cp ~/github/otf-testdata/pdm_testdata/maps/alignmentMaps/nlpLinks.csv  $PDM_ROOT/in/maps/align
sleep 1
cp ~/github/otf-testdata/pdm_testdata/maps/alignmentMaps/providerItems.csv  $PDM_ROOT/in/maps/align
sleep 1
cp ~/github/otf-testdata/pdm_testdata/maps/levelMaps/scaleMap.csv  $PDM_ROOT/in/maps/level
sleep 1
cp ~/github/otf-testdata/pdm_testdata/maps/levelMaps/scoresMap.csv  $PDM_ROOT/in/maps/level

# attach to the session
att

# # to attach another console to monitor...
# # tmux a -t otfpdm
# # then Ctrl-b, w to list all windows
# #
# #Ctrl-b, d to detach monitor from session
# #
# # to shutdown the whole tmux session 
# # 
# # tmux kill-session -t otfpdm
# # 
# # note post-kill you may still have to force nats to quit,
# # often better to go to session in tmux and stop nats there before
# # issuing kill-session
# # 





