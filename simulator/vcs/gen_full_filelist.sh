#!/bin/bash
write_file() {
  file="$1"
  output_sv="$2"
  output_vhd="$3"

  filename="${line##*/}"
  extension="${filename##*.}"

  if [ "$extension" = "vhd" ]
  then
    eval echo $file >> "$output_vhd"
  else
    eval echo $file >> "$output_sv"
  fi
}

parse_filelist () {
  input="$1"
  output_sv="$2"
  output_vhd="$3"
  echo "Entering ${1}"
  #echo "(Debug) Entering ${1}" >> "$output_sv"
  while IFS= read -r line || [ -n "$line" ]
  do
    if [ "${line:0:1}" != "#" ] && [ "${line:0:2}" != "//" ] && [ "${line:0:1}" != "" ]
    then
      if [ "${line:0:2}" = "-f" ] || [ "${line:0:2}" = "-F" ]
      then
        # Append current directory if needed
        if [ "${line:3:1}" = "$" ]
        then
          newfile=$(eval echo ${line:3})
        else
          dir=$(eval echo $(dirname $1))
          newfile=$(eval echo $dir/${line:3})
        fi
        # Recursively enter all filelists
        parse_filelist ${newfile} ${output_sv} ${output_vhd}
      else
        # If the line is an +incdir+ we may need to fix the path
        if [ "${line:0:8}" = "+incdir+" ]
        then
          if [ "${line:8:1}" = "$" ]
          then
            write_file $line "$output_sv" "$output_vhd"
          else
            dir=$(eval echo $(dirname $1))
            write_file "+incdir+$dir/${line:8}" "$output_sv" "$output_vhd"
          fi
        else
          # Append current directory if needed
          if [ "${line:0:1}" = "$" ] || [ "${line:0:1}" = "+" ]
          then
            write_file $line "$output_sv" "$output_vhd"
          else
            dir=$(eval echo $(dirname $1))
            write_file "$dir/$line" "$output_sv" "$output_vhd"
          fi
        fi
      fi
    fi
  done < "$input"

  echo "Exiting ${1}"

}

out_filelist_sv="${PARSED_FLIST}"
out_filelist_vhd="${PARSED_FLIST}_vhd.f"
rm -r "$out_filelist_sv" "$out_filelist_vhd"
touch "$out_filelist_sv" "$out_filelist_vhd"
parse_filelist "${FLIST_PATH}" "$out_filelist_sv" "$out_filelist_vhd"
