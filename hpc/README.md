# Running Alphafold3 on CHTC

This directory has two pipelines for running Alphafold3 on CHTC. It uses an
apptainer container (5GB) in two pipelines.

1. The data pipeline searches the genetic databases for matches of interest. It
   copies and decompresses the databases (252GB --> 650GB) to an execute node
   and runs the searches in parallel there. No GPU is needed for this pipeline
2. The inference pipeline takes the output of the data pipeline and creates a
   structure using a GPU


## **Important Notes**

* **Obtain the Alphafold3 model parameters first**: The inference pipeline needs
  [your own copy of the Model
  Parameters](../README.md#obtaining-model-parameters) to run. Google Deepmind
  has terms of use and you need to agree to these, download and save the
  parameters to your own staging directory. Make sure that this file is
  protected by your own file permissions `chmod 600 af3.bin*` and then
  edit `MODEL_PARAM_FILE` variable in the
  [inference pipeline execute script](./inference_pipeline.sh) to point to it.
* **Batch jobs to avoid using excess CHTC resouces**: Contrary to the usual CHTC
  approach of slicing jobs finely we need to batch jobs as much as possible to
  avoid transferring too much data to/from the staging directory. It is
  possible to put multiple json config files in each of the the input
  directories [job1/data_inputs](./job1/data_inputs/) and
  [job1/inference_inputs](./job1/inference_inputs/) and also create multiple
  `job` directories and run them all at the same time.
* **Avoid coping data**: The apptainer container and the databases in
  `/staging/groups/glbrc_alphafold/af3/` are created and downloaded from public
  sources and are readable by anyone who can access the staging directory. This
  is done so that there is no need to make any copies of this data on the
  staging directory. According to the TERMS of USE, only the model parameters
  need your own copies as you cannot run this software without receiving the
  model parameters directly from Google Deepmind.


## How to use these pipelines
1. Obtain the model parameters, put it in your own staging directory and
   protect it with your file permissions. `chmod 600 af3.bin.zst`. Do not use
   squid as this data should be private and not be public.
2. Download the following files to your chtc submit server home directory
   * [data_pipeline.sh](./data_pipeline.sh)
   * [data_pipeline.sub](./data_pipeline.sub)
   * [inference_pipeline.sh](./inference_pipeline.sh)
   * [inference_pipeline.sub](./inference_pipeline.sub)
   * [Makefile](./Makefile) # optional to help run the scripts
3. Create the input directories as a sub directory of the directory that you
   downloaded the above files into.
   ```shell
    mkdir -p job1/data_inputs job1/inference_inputs
   ```
4. Edit the `MODEL_PARAM_FILE` variable in `inference_pipeline.sh` to point
   to the model parameters you got from Google Deepmind in Step 1.
5. Put the config `json` files in the in the [job1/data_inputs/](./job1/data_inputs/)
   directory. An example config to test is available as
   [`fold_input.json`](./test/input/fold_input.json) in
   the [(README.md file for Alphafold3](../README.md)
6. Run a test with the small databases first
   ```shell
   condor_submit USE_SMALL_DB=1 data_pipeline.sub
   # check and then delete test output files
   ```
7. If everything looks good, then run the full data pipeline and inference
   pipeline
   ```shell
   condor_submit data_pipeline.sub
   mv *.data_pipeline.tar.gz inference_inputs/
   condor_submit inference_pipeline.sub
   ```

## Notes on recreating steps used to create these instructions

These notes below are only needed in case someone wants to recreate building
the apptainer container or the databases


### Creating the apptainer container
The latest version of the apptainer container is stored at
`/staging/groups/glbrc_alphafold/af3/alphafold3.sif` and the commands below are
just in case anyone needs to build it for themselves. This container is built
using the Google Deepmind Alphafold3 publically available code and it's use
should be governed by the same terms of use.

```shell
# Build the container on your own machine (if you want to)
# Docker needs around 11GB of memory to run
# On an 8GB machine, enable swapspace of 4GB so that the `build_data` command
# does not get killed
sudo docker build -t alphafold3 -f docker/Dockerfile .
# apptainer needs a lot less memory but needs around 30GB of disk space
# mostly in it's tmp directory. Can be set with APPTAINER_CACHE and TMPDIR
sudo apptainer build alphafold3.sif docker-daemon://alphafold3:latest
```

### Creating small databases for testing

```
# conda env utils has zstd so activate it
eval "$(micromamba shell hook --shell bash)"
micromamba activate utils


compressed_db_dir= /staging/groups/glbrc_alphafold/af3/db

small_db_dir=/staging/groups/glbrc_alphafold/af3/db_small
mkdir -p ${small_db_dir}
touch "${small_db_dir}/test.zst"
/bin/rm "${small_db_dir}"/*.zst

pushd "$compressed_db_dir"
for archive in *.zst
do
  echo processing "${archive}"
  zstdcat -d "${archive}" | ~/bin/subsample-fasta -n 1000 | zstd - -o "${small_db_dir}/${archive}"
done
popd



```
