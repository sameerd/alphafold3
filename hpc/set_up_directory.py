# Given a multifasta, this script will create a folder named job1...jobN with subfolders named data_inputs and inference_inputs, and create a custom json file for each fasta sequence.
# for example, let test.fasta look like this:
# >sequence1
# ABCDEFG
# >sequence2
# HIJKLMNOP
# >sequence3
# QRSTUV
# This script will create these files:
# job1
# ├── data_inputs
# │   └── fold_input.json
# └── inference_inputs
# job2
# ├── data_inputs
# │   └── fold_input.json
# └── inference_inputs
# job3
# ├── data_inputs
# │   └── fold_input.json
# └── inference_inputs

## USAGE ##
# chmod +x set_up_directory.py
# python set_up_directory test.fasta


import json
from Bio import SeqIO
import os
import argparse

def fasta_to_json(fasta_file):
    sequences = list(SeqIO.parse(fasta_file, "fasta"))
    
    for i, record in enumerate(sequences, start=1):
        job_dir = f"job{i}"
        data_inputs_dir = os.path.join(job_dir, "data_inputs")
        inference_inputs_dir = os.path.join(job_dir, "inference_inputs")
        
        os.makedirs(data_inputs_dir, exist_ok=True)
        os.makedirs(inference_inputs_dir, exist_ok=True)
        
        data = {
            "name": record.id,
            "sequences": [
                {
                    "protein": {
                        "id": ["A"],
                        "sequence": str(record.seq)
                    }
                }
            ],
            "modelSeeds": [1],
            "dialect": "alphafold3",
            "version": 1
        }
        
        json_filename = os.path.join(data_inputs_dir, "fold_input.json")
        with open(json_filename, "w") as json_file:
            json.dump(data, json_file, indent=2)
    
    print(f"JSON files saved under respective job folders in the current directory")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert FASTA file to JSON format with structured job directories.")
    parser.add_argument("fasta_file", type=str, help="Path to the input FASTA file")
    
    args = parser.parse_args()
    fasta_to_json(args.fasta_file)
