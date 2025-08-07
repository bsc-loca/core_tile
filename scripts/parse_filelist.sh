#!/bin/bash

# Define the root file (filelist.f) and root folder
root_file=$(realpath "$1")
root_folder=$(dirname "$root_file")

# Define HPDCACHE_DIR as $root_folder/rtl/dcache
HPDCACHE_DIR="$root_folder/rtl/dcache"

# Declare an associative array to store variables
declare -A variables
variables["HPDCACHE_DIR"]="$HPDCACHE_DIR"

# Output file where the parsed filelist will be stored
output_file="parsed_filelist.f"
> "$output_file"  # Clear the output file at the start

# Function to substitute variables in file paths
substitute_variables() {
    local line=$1
    for var in "${!variables[@]}"; do
        line=$(echo "$line" | sed "s|\${$var}|${variables[$var]}|g")
    done
    echo "$line"
}

# Function to process a filelist
process_filelist() {
    local filelist=$1
    local filelist_dir=$(dirname "$filelist")  # Get the directory of the current filelist

    # Read the filelist line by line, including the last line if it lacks a newline
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Ignore lines that start with "//" (these are commented paths)
        if [[ "$line" =~ ^// ]]; then
            continue
        fi

        # Ignore empty lines or lines that are purely comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            continue
        fi

        # If the line defines a variable (e.g., HPDCACHE_DIR=...)
        if [[ "$line" =~ ^[A-Z_]+= ]]; then
            var_name=$(echo "$line" | cut -d'=' -f1)
            var_value=$(echo "$line" | cut -d'=' -f2)
            var_value=$(substitute_variables "$var_value") # Substitute any existing variables
            variables["$var_name"]="$var_value"
            continue
        fi

        # If the line starts with -f or -F, process the referenced filelist
        if [[ "$line" =~ ^-f ]] || [[ "$line" =~ ^-F ]]; then
            filelist_path=$(echo "$line" | cut -d' ' -f2)
            filelist_path=$(substitute_variables "$filelist_path") # Substitute variables in the file path

            # Make the filelist path absolute if it's relative
            if [[ ! "$filelist_path" =~ ^/ ]]; then
                filelist_path="$filelist_dir/$filelist_path"
            fi

            if [[ -f "$filelist_path" ]]; then
                process_filelist "$filelist_path"
            else
                echo "Warning: Cannot find filelist $filelist_path"
            fi
            continue
        fi

        # Substitute variables in the file paths
        line=$(substitute_variables "$line")

        # Trim leading and trailing spaces
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Make the file path absolute if it's relative
        if [[ ! "$line" =~ ^/ ]]; then
            line="$filelist_dir/$line"
        fi

        # If the line contains an RTL (.v, .sv, .vhdl), header (.h), or system verilog header (.svh) file, store its absolute path in the output file
        if [[ "$line" =~ \.v$ || "$line" =~ \.sv$ || "$line" =~ \.vhdl$ || "$line" =~ \.h$ || "$line" =~ \.svh$ ]]; then
            if [[ -f "$line" ]]; then
                realpath "$line" >> "$output_file"
            else
                echo "Warning: Cannot find file $line"
            fi
        fi
    done < "$filelist"
}

# Check if the main filelist exists
if [[ ! -f "$1" ]]; then
    echo "Error: File $1 not found"
    exit 1
fi

# Output root_file and HPDCACHE_DIR variables
echo "Root file: $root_file"
echo "HPDCACHE_DIR: $HPDCACHE_DIR"

# Call the processing function with the main filelist
process_filelist "$root_file"

# Notify the user where the parsed filelist is saved
echo "Parsed filelist saved in $output_file"
