
pass:

clean:
	rm -f logs/*

test_data_pipeline:
	condor_submit USE_SMALL_DB=1 data_pipeline.sub	

test_inference_pipeline:
	condor_submit inference_pipeline.sub	

data_pipeline:
	condor_submit data_pipeline.sub


