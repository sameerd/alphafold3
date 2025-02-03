#!/bin/bash

#set -x #for complete debugging

# STAGING_DIR is used to find the Singularity image (and databases)
# It can be left unused by specifing a container to run in
# and using --extracted_database_path
readonly STAGING_DIR=/staging/groups/glbrc_alphafold/af3

DB_DIR_STUB=db

# SINGIMG is used if we want to find a container. The script will 
# first look in a local directory and then the staging directory for it.
SINGIMG=""

# By default we copy containers and params to a working directory 
# on the local execute node. If working off a single file system 
# (scarcity) we can turn this off with --no_copy
COPY_BINARIES=1

VERBOSE_LEVEL=1 # 0 = silent, 1 = info, 2 = verbose

# By default we create a working directory called work.random
# Ideally this should be set to 
# --work_dir_ext $(ClusterId)_$(ProcID)  in the submit file
# but not needed if we are sure that multiple copies of this script
# will not overwrite each other
WORK_DIR_EXT="random"

# full path to extracted database
# overrides $STAGING_DB_DIR and $DB_DIR_STUB
EXTRACTED_DATABASE_PATH=""

function printstd() { echo "$@"; }
function printerr() { echo "ERROR: $@" 1>&2; }

function printinfo() {
  if [[ $VERBOSE_LEVEL -ge 1 ]]; then
    printstd "INFO: $@"
  fi
}
function printverbose() {
  if [[ $VERBOSE_LEVEL -ge 2 ]]; then
    printstd "DEBUG: $@"
  fi
}

ARGS="$@"

while [[ $# -gt 0 ]]; do
  case $1 in
     -w|--work_dir_ext)
      WORK_DIR_EXT="$2"
      printinfo "Setting WORK_DIR_EXT : ${WORK_DIR_EXT}"
      shift # past argument
      shift # past value
      ;;
    -v|--verbose)
      VERBOSE=2
      printinfo "Setting PRINT_SUMMARY and VERBOSE on"
      shift # past argument
      ;;
     -s|--silent)
      VERBOSE=0
      printinfo "Setting PRINT_SUMMARY and VERBOSE off" # this will not print
      shift # past argument
      ;;
     -n|--no_copy)
      COPY_BINARIES=0
      printinfo "Not copying singularity container or databases"
      shift # past argument
      ;;
     -c|--container)
      SINGIMG="$2"
      printinfo "Will run inside container: $SINGIMG"
      shift # past argument
      shift # past value
      ;;
     --smalldb)
      DB_DIR_STUB=db_small
      shift # past argument
      ;;
     -d|--extracted_database_path)
      EXTRACTED_DATABASE_PATH=`realpath "$2"`
      printinfo "Setting EXTRACTED_DATABASE_PATH"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

printinfo "Script         : $0"
printinfo "Running on     : `whoami`@`hostname`"
printinfo "Arguments      : $ARGS"
printinfo "Script dir     : $(dirname $0)"
printinfo "DB_DIR_STUB    : $DB_DIR_STUB"

readonly STAGING_DB_DIR="${STAGING_DIR}/${DB_DIR_STUB}"

readonly WORK_DIR="work.${WORK_DIR_EXT}"

printinfo "WORK_DIR   : `realpath $WORK_DIR`"
printverbose "Creating workdir and subdirectories : ${WORK_DIR}"
mkdir -p "${WORK_DIR}"
pushd "${WORK_DIR}" > /dev/null
mkdir -p af_input af_output models public_databases tmp
popd

readonly WORK_INPUT_DIR="${WORK_DIR}/af_input"
# prepare input directory
if compgen -G "*.json"  > /dev/null; then
  mv *.json "${WORK_INPUT_DIR}"
else
  printerr "Cannot find any input files matching " \
           "*.json in directory : $(dirname $0)"
  exit 1
fi

## copy the container if we are going to run commands inside it
IMG_EXE_CMD="" # default is to not pipe commands through container
SINGIMG_PATH=""
if [[ -n "$SINGIMG" ]] ; then
  printverbose "Calling apptainer externally : ${SINGIMG}"
  if [[ "$COPY_BINARIES" -ne 0 ]] ; then
    printverbose "Copying container to WORK_DIR"
    if [ -f "$SINGIMG" ]; then 
      printverbose "Copying container from local directory"
      cp "${SINGIMG}" "${WORK_DIR}"/
      SINGIMG_PATH="${WORK_DIR}/${SINGIMG}"
    else # container is not in the local directory, check if it is in staging
      if [ -f ${STAGING_DIR}/${SINGIMG} ]; then
        printverbose "Copying container from staging directory"
        cp "${STAGING_DIR}/${SINGIMG}" "${WORK_DIR}"/ 
        SINGIMG_PATH="${WORK_DIR}/${SINGIMG}"
      else #not in staging
        printerr "Cannot find container to copy : $SINGIMG"
        exit 1
      fi # SINGIMG is not available to copy
    fi
  else # Do not copy binaries
    if [ -f "$SINGIMG" ]; then 
      printverbose "Container found. Not copying to workdir : $SINGIMG"
      SINGIMG_PATH="${SINGIMG}"
    else # container not found
      printerr "Trying to run in container (not found) : $SINGIMG"
      exit 1
    fi
  fi
  IMG_EXE_CMD="apptainer exec --nv ${SINGIMG_PATH}"
else
  printverbose "Not calling apptainer as we are inside the container"
fi

printinfo "SINGIMG_PATH   : $SINGIMG_PATH"
printinfo "IMG_EXE_CMD    : $IMG_EXE_CMD"


if [ -z "$EXTRACTED_DATABASE_PATH" ] ; then
  printverbose "Preparing to extract the databases"

  ## prepare public_databases directory
  ## Will do 8 file copy/uncompress in parallel so we request 8 cpus
  printverbose "Start decompressing : pdb_2022_09_28_mmcif_files"
  cat "${STAGING_DB_DIR}"/pdb_2022_09_28_mmcif_files.tar.zst | \
          ${IMGEXEC} tar --no-same-owner --no-same-permissions \
          --use-compress-program=zstd -xf - --directory=public_databases/ &
  
  for NAME in mgy_clusters_2022_05.fa \
              bfd-first_non_consensus_sequences.fasta \
              uniref90_2022_05.fa uniprot_all_2021_04.fa \
              pdb_seqres_2022_09_28.fasta \
              rnacentral_active_seq_id_90_cov_80_linclust.fasta \
              nt_rna_2023_02_23_clust_seq_id_90_cov_80_rep_seq.fasta \
              rfam_14_9_clust_seq_id_90_cov_80_rep_seq.fasta ; do
    printinfo "Start decompressing: '${NAME}'"
    cat "${STAGING_DB_DIR}/${NAME}.zst" | \
        ${IMGEXEC} zstd --decompress > "public_databases/${NAME}" &
  done
  
  wait # for all decompression to finish
  EXTRACTED_DATABASE_PATH="${WORK_DIR}/public_databases"
  printverbose "Completed database installation"
fi

if [[ -n "$SINGIMG" ]] ; then
  apptainer exec \
    --bind "${WORK_DIR}/af_input":/root/af_input \
    --bind "${WORK_DIR}/af_output":/root/af_output \
    --bind "${WORK_DIR}/models":/root/models \
    --bind "${EXTRACTED_DATABASE_PATH}":/root/public_databases \
    --cwd /app/alphafold \
    ${SINGIMG} \
    python run_alphafold.py \
    --db_dir=/root/public_databases \
    --run_data_pipeline=true \
    --run_inference=false \
    --input_dir=/root/af_input \
    --model_dir=/root/models \
    --output_dir=/root/af_output
else # we must already be in the container
  WORK_DIR_FULL_PATH=`realpath ${WORK_DIR}` # full path to working directory
  EXTRACTED_DATABASE_FULL_PATH=`realpath "${EXTRACTED_DATABASE_PATH}"`
  pushd /app/alphafold
  python run_alphafold.py \
       --db_dir="${EXTRACTED_DATABASE_FULL_PATH}" \
       --model_dir="${WORK_DIR_FULL_PATH}/models" \
       --run_data_pipeline=true \
       --run_inference=false \
       --input_dir="${WORK_DIR_FULL_PATH}/af_input" \
       --output_dir="${WORK_DIR_FULL_PATH}/af_output" 
  popd # back to execution directory
fi

printverbose "Finished running Alphafold3 data pipeline. Packing up output dir"
# tar up the output directory - one tar for each job. These get returned
shopt -s nullglob # we do not want an empty match below
for output_dir in "${WORK_DIR}/af_output"/*/ ;
do
  output_name_base="$(basename ${output_dir})"
  printinfo "Compressing : $output_name_base"
  tar zcf "${output_name_base}".data_pipeline.tar.gz -C "${output_dir}" .
done

# clean up
printverbose "Cleaning up working directory"
rm -rf "${WORK_DIR}"
rm -rf .bash_history .bashrc .lesshst .viminfo
printverbose "Done"

