

SCARCITY=
ifneq (,$(findstring scarcity, ${HOSTNAME}))
   SCARCITY="_scarcity"
   $(info *********************************)
   $(info ****** Running on Scarcity ******)
   $(info *********************************)
endif

pass:

clean:
	rm -f logs/*

deepclean: clean
	rm -f *.tar.gz

test_data_pipeline:
	condor_submit USE_SMALL_DB=1 data_pipeline$(SCARCITY).sub

test_data_flock:
	condor_submit USE_SMALL_DB=1 FLOCK=1 data_pipeline.sub

data_pipeline:
	condor_submit data_pipeline$(SCARCITY).sub

flock_data_pipeline:
	condor_submit FLOCK=1 data_pipeline.sub

# TODO: Fixme
sweep_data_pipe_outputs:
	/bin/bash sweep_data_pipe_outputs.sh

inference_pipeline:
	condor_submit inference_pipeline$(SCARCITY).sub



