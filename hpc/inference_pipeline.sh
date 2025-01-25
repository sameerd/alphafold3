#!/bin/bash

#set -x
readonly CWD=$PWD
readonly STAGING_DIR=/staging/groups/glbrc_alphafold/af3

SINGIMG=""

# this file should be protected by your staging dir unix permissions
MODEL_PARAM_FILE=/staging/dcosta2/af3/weights/af3.bin

PRINT_INFO=0
function printinfo {
  if [[ "$PRINT_INFO" -ne 0 ]] ; then
    echo $1
  fi
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--printinfo)
      PRINT_INFO=1
      printinfo "Setting printinfo on"
      shift # past argument
      ;;
    -r|--run_in_container)
      SINGIMG="$2"
      printinfo "Will copy container $SINGIMG and run inside it"
      shift # past argument
      shift # past value
      ;;
    -m|--model_param_file)
      MODEL_PARAM_FILE="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done



mkdir -p work
pushd work

mkdir -p af_input af_output models public_databases

# prepare input directory
for filename in ../*.data_pipeline.tar.gz ;
do
 printinfo "Extracting : ${filename}"
 tar zxf "${filename}" -C af_input/
 rm "${filename}"
done

## copy the container if we are going to run commands inside it
IMGEXEC="" # default is to not pipe commands through container
if [[ -n "$SINGIMG" ]] ; then
  printinfo "Copying container : $SINGIMG"
  cp "${STAGING_DIR}"/${SINGIMG} .
  IMGEXEC="apptainer exec ${SINGIMG}"
else
  printinfo "Running inside the container : not copying container"
fi

if [[ ${MODEL_PARAM_FILE} == *.zst ]]; then
  cat "${MODEL_PARAM_FILE}"  | \
        ${IMGEXEC} zstd  --decompress > models/af3.bin
  printinfo "Decompressing model weights : ${MODEL_PARAM_FILE}"
else
  cp "${MODEL_PARAM_FILE}" models/af3.bin
  printinfo "Copying model weights : ${MODEL_PARAM_FILE}"
fi

if [[ -n "$SINGIMG" ]] ; then
  apptainer exec \
     --bind af_input:/root/af_input \
     --bind af_output:/root/af_output \
     --bind models:/root/models \
     --bind public_databases:/root/public_databases \
     --cwd /app/alphafold \
     --nv \
     ${SINGIMG} \
     python run_alphafold.py \
     --db_dir=/root/public_databases \
     --model_dir=/root/models \
     --run_data_pipeline=false \
     --run_inference=true \
     --input_dir=/root/af_input \
     --output_dir=/root/af_output
else
  workdir=`realpath .`
  pushd /app/alphafold
  python run_alphafold.py \
       --db_dir=${workdir}/public_databases \
       --model_dir=${workdir}/models \
       --run_data_pipeline=false \
       --run_inference=true \
       --input_dir=${workdir}/af_input \
       --output_dir=${workdir}/af_output
  popd # back to workdir
fi

popd # back to home dir


# tar up the output directory - one tar for each job. These get returned

shopt -s nullglob # we do not want an empty match below
for output_name in work/af_output/* ;
do
  output_name_base="${output_name##*/}"
  printinfo "Compressing : $output_name_base"
  tar zcf "${output_name_base}".inference_pipeline.tar.gz -C "${output_name}" .
done

# clean up
rm -rf work
rm -rf .bash_history .bashrc .lesshst .viminfo

