#!/bin/bash
set -euo pipefail #should stop script if anything fails


START_I=${1:-0} #time index referring to first (post-spin) run, default 0 or set in call in sub script
TOTAL_STEPS=26
 
OBSFILE='dummy' #NOW SET IN nemo-pdaf config file for each obs type #needed in several places
MEMBERS=18 #for testing

#Set first pre-assim time step length here (end 2009 - 7th Oct 2010 for us)
INIT_NXTRNTS=13440
INIT_STARTSTRING=20100101
#for time_counter in range(FIRST_SETP:FIRST_STEP+TOTAL_Steps):
for ((i=START_I; i<TOTAL_STEPS; i++)); do
###for ((i=95; i<last_step; i++)); do
	#define the step counter here 
	COUNTER=$i #not really needed now we start at 0, but leaving in for now
	CPONE=$((i +1))
       	echo "i=$i COUNTER=$COUNTER CPONE=$CPONE"


	#DEFINE INDIR,INSTRING,INICESTRNG, OUTDIR, OUTSTRING, OUTICESTRING DEPENDING IN TIME_COUNTER AND next run time AND START_string
	#INDIR="./restart_step${COUNTER}"
	if [ "$i" -eq 0 ]; then
	     START_STRING=$INIT_STARTSTRING
             INSTRING="ORCA1_00035040_orca1_enssp_end"
	     INICESTRING="ORCA1_00035040_orca1_ice_enssp_end"
	     NXTRNTS=$INIT_NXTRNTS

             RUN_SCRIPT=./run_ens_general_step_sublimit.sh   # your special version
             INDIR="./orca1_ensspinup_end"
        else
		INDIR="./restart_step${COUNTER}"

		    source /work/n01/n01/elicoo/myvenv/bin/activate
		if [ "$i" -eq 1 ]; then
			LAST_NXTRNTS=$INIT_NXTRNTS                       # the i=0 run
		else
		        LAST_NXTRNTS=$(python get_runtime.py "$((i-2))") # run length of cycle i-1
		fi
		NXTRNTS=$(python get_runtime.py "$((i-1))")
		START_STRING=$(python get_next_start_string.py "$((i-1))")
		deactivate

		INSTRING=$(printf "ORCA1_%08d_ens_step%d" "$LAST_NXTRNTS" "$COUNTER")
		INICESTRING=$(printf "ORCA1_%08d_ens_ice_step%d" "$LAST_NXTRNTS" "$COUNTER")

		RUN_SCRIPT=./save_ints_run_ens_general_step_sublimit.sh

        fi

	OUTDIR="./restart_step$CPONE"
	OUTSTRING="ens_step$CPONE"
	OUTICESTRING="ens_ice_step$CPONE"
        #echo "INDIR=$INDIR"
	echo "INDIR=$INDIR   OUTDIR=$OUTDIR"
	echo "INSTRING=$INSTRING"
	echo "OUTSTRING=$OUTSTRING"



	#RUN NEMO ENSEMBLE (NEEDS instring, inicestring, indir, outstring, outicestring, outdir, startstring), NXTRNTS
	#./run_ens_general_step_sublimit.sh "$INDIR" "$INSTRING" "$INICESTRING" "$OUTDIR" "$OUTSTRING" "$OUTICESTRING" "$NXTRNTS" "$START_STRING" "$MEMBERS"
	"$RUN_SCRIPT" "$INDIR" "$INSTRING" "$INICESTRING" "$OUTDIR" "$OUTSTRING" "$OUTICESTRING" "$NXTRNTS" "$START_STRING" "$MEMBERS"
	#^^ SHOULD SOMEWHERE PUT IN A STOP IF THE ABOVE FAILS, otherwise will cycle through all the timesteps - DONE
	#would be good to gather up the output_ice_init files here, or at least move them to the restart_step folder for plotting later

         
	#DO ASSIMILATION (NEEDS INDIR, INSTRING, INICESTRING, OBSFILE)
	echo "Starting assimilation"
	
	ASSIM_TIME=$((i+1))
	PREFIX=$(printf "ORCA1_%08d_" "$NXTRNTS")
	echo "ASSIM_TIME=$ASSIM_TIME  PREFIX=$PREFIX"
	echo "Using $OUTDIR, $OUTSTRING, $OUTICESTRING, $OBSFILE"
	./run_general_assimilation.sh "$OUTDIR" "$PREFIX" "$OUTSTRING" "$OUTICESTRING" "$ASSIM_TIME" "$OBSFILE" "$MEMBERS"

	#ADD INCREMENTS needs folder, string and num_ens
        OUTLONGSTRING=${PREFIX}${OUTICESTRING}
	echo "Adding increments using $OUTDIR $OUTLONGSTRING $MEMBERS" #Addin increments using ./restart_step1 ORCA2_00000360_ 4

	source  /work/n01/n01/elicoo/myvenv/bin/activate
	python add_incs_ALL.py "$OUTDIR" "$OUTLONGSTRING" "$MEMBERS"
	deactivate
        
	echo "Increments added"

	#KEEP THIS value of NXTRNTS and START_STRING for the following instring
	LAST_NXTRNTS="$NXTRNTS"
	LAST_START_STRING="$START_STRING" #??are the types OK here?? **don't need this one actually
	
done










