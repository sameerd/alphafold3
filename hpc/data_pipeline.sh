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

readonly STAGING_DIR=/staging/groups/glbrc_alphafold/af3
if [[ "$2" -eq 0 ]];
then
  readonly DB_DIR_STUB=db
else
  readonly DB_DIR_STUB=db_small
fi
printinfo "Setting up database : $DB_DIR_STUB"

readonly STAGING_DB_DIR="${STAGING_DIR}/${DB_DIR_STUB}"

mkdir work
pushd work

mkdir -p af_input af_output models public_databases

# prepare input directory
mv ../*.json af_input/

## copy the container
cp "${STAGING_DIR}"/${SINGIMG} .

## prepare public_databases directory
printinfo "Decompressing pdb_2022_09_28_mmcif_files"
cat "${STAGING_DB_DIR}"/pdb_2022_09_28_mmcif_files.tar.zst | \
        apptainer exec ${SINGIMG} \
        tar --no-same-owner --no-same-permissions \
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
      apptainer exec ${SINGIMG}  \
        zstd --decompress > "public_databases/${NAME}" &
done

wait
printinfo "Completed database installation"

apptainer exec \
   --bind af_input:/root/af_input \
   --bind af_output:/root/af_output \
   --bind models:/root/models \
   --bind public_databases:/root/public_databases \
   --cwd /app/alphafold \
   alphafold3.sif \
   python run_alphafold.py \
   --db_dir=/root/public_databases \
   --model_dir=/root/models \
   --run_data_pipeline=true \
   --run_inference=false \
   --input_dir=/root/af_input \
   --model_dir=/root/models \
   --output_dir=/root/af_output 

popd

# tar up the output directory - one tar for each job. These get returned
shopt -s nullglob # we do not want an empty match below
for output_name in work/af_output/*
do
  output_name_base="${output_name##*/}"
  printinfo "Compressing : $output_name_base"
  tar zcf "${output_name_base}".data_pipeline.tar.gz -C "${output_name}" .
done

# clean up
rm -rf work
rm -rf .bash_history .bashrc .lesshst

