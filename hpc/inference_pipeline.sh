#!/bin/bash

#set -x
readonly CWD=$PWD

readonly SINGIMG=alphafold3.sif

PRINT_INFO=$1
function printinfo {
  if [[ "$PRINT_INFO" -ne 0 ]] ; then
    echo $1
  fi
}
printinfo "Checking if printinfo is on"

readonly STAGING_DIR=/staging/dcosta2/af3

mkdir work
pushd work

mkdir -p af_input af_output models public_databases 

# prepare input directory
for filename in ../*.data_pipeline.tar.gz ;
do
 printinfo "Extracting : ${filename}"
 tar zxf "${filename}" -C af_input/
 rm "${filename}"
done

## copy the container
cp "${STAGING_DIR}"/${SINGIMG} .

printinfo "Extracting model weights"
cat "${STAGING_DIR}"/weights/af3.bin.zst  | \
        apptainer exec ${SINGIMG} \
        zstd  --decompress > models/af3.bin

apptainer exec \
   --bind af_input:/root/af_input \
   --bind af_output:/root/af_output \
   --bind models:/root/models \
   --bind public_databases:/root/public_databases \
   --cwd /app/alphafold \
   --nv \
   alphafold3.sif \
   python run_alphafold.py \
   --db_dir=/root/public_databases \
   --model_dir=/root/models \
   --run_data_pipeline=false \
   --run_inference=true \
   --input_dir=/root/af_input \
   --model_dir=/root/models \
   --output_dir=/root/af_output 

popd

# tar up the output directory - one tar for each job. These get returned
for output_name in work/af_output/*
do
  output_name_base="${output_name##*/}"
  printinfo "Compressing : $output_name_base"
  tar zcf "${output_name_base}".inference_pipeline.tar.gz -C "${output_name}" .
done

# clean up
rm -rf work
rm -rf .bash_history .bashrc .lesshst

