#!/bin/bash
IFS=$'\n'

printUsage() {
  echo "Usage: gpt-clean <action>"
  echo
  echo "Actions:"
  echo "get-json <file> - given <file>, find the corresponding json file."
  echo "sanitize-all - sanitize all jpg/jpeg/png/gif/heic/mts files"
}

getJsonPath() {
  local regex bn f nf path

  # remove "-edited(?)" from file name
  f=$(echo "$1"|sed -E "s/(.*)(-edite?d?)(\([0-9]+\))?(\..+)$/\1\4/gi")
  bn=$(basename "$f")
  path=$(dirname "$f")

  nf="$f.json"
  if [ -f "$nf" ]; then
    echo "$nf"
  else
    nf=$(echo "$f"|sed -E "s/.[^.]+$/.json/gi")
    if [ -f "$nf" ]; then
      echo "$nf"
    else
      nf="$path/${bn:0:46}.json"
      if [ -f "$nf" ]; then
        echo "$nf"
      else
        regex="^(.+)(\([0-9]+\))(\..+)$"
        if echo "$bn"|grep -Eq "$regex"; then
          nf="$path/$(echo "$bn"|sed -E "s/$regex/\1\3\2.json/gi")"
          if [ -f "$nf" ]; then
            echo "$nf"
          else
            echo "JSON_NOT_FOUND"
          fi
        else
          echo "JSON_NOT_FOUND"
        fi
      fi
    fi
  fi
}

sanitizeAll() {
  local mime dto jsonFile ptt count=0
  for f in $(find .|grep -Ei "\.(jpg|jpeg|png|gif|heic)$");do
    if [ ! -d "$f" ]; then
      ((count++))
      mime=$(exiftool -MimeType -s3 "$f")

      # convert erroneous pngs and jpegs back to their intended formats
      if echo "$f"|grep -Eiq "\.(jpg|jpeg)$" && [ "$mime" = "image/png" ]; then
        echo "$f - is a png, converting to jpeg"
        magick -quality 100 "$f" "$f"
      elif echo "$f"|grep -Eiq "\.(png)$" && [ "$mime" = "image/jpeg" ]; then
        echo "$f - is a jpeg, converting to png"
        magick -quality 100 "$f" "$f"
      fi

      # for files missing DateTimeOriginal, insert them via json file's photoTakenTime
      # note: apple photos reads DateTimeOriginal from jpg/heic/png but not gif on import. for gif, it reads from the file's modified date, so we are setting both for all files just in case.
      dto=$(exiftool -DateTimeOriginal -s3 "$f")
      if [ -z "$dto" ]; then
        jsonFile=$(getJsonPath "$f")
        if [ ! -f "$jsonFile" ]; then
          echo "$f - does not contain DateTimeOriginal but unable to find json file at $jsonFile"
        else
          ptt=$(gdate -d "@$(jq -r '.photoTakenTime.timestamp' < "$jsonFile")" -Iseconds)
          echo "$f - does not contain DateTimeOriginal, writing exif dates and file modified date as $ptt"
          exiftool -q -overwrite_original -AllDates="$ptt" -FileModifyDate="$ptt" "$f"
        fi
      elif echo "$f"|grep -Eiq "\.(gif)$"; then
        echo "$f - setting file modified date to match its DateTimeOriginal"
        exiftool -q -overwrite_original "-FileModifyDate<DateTimeOriginal" "$f"
      fi
    fi
  done

  # convert mts files, which apple photos doesn't import, into mp4 files
  for f in $(find .|grep -Ei "\.(mts)$");do
    if [ ! -d "$f" ]; then
      ((count++))
      jsonFile=$(getJsonPath "$f")
      if [ ! -f "$jsonFile" ]; then
        echo "$f - unable to find json file at $jsonFile"
      else
        ptt=$(gdate -d "@$(jq -r '.photoTakenTime.timestamp' < "$jsonFile")" -Iseconds)
        newFile=$(echo "$f"|sed -E "s/\.mts$/.mp4/gi")
        echo "$f - transcoding to mp4 and setting creation_time and file modified date as $ptt"
        ffmpeg -hide_banner -loglevel error -i "$f" -c:v hevc -x265-params log-level=error -tag:v hvc1 -crf 17 -metadata creation_time="$ptt" "$newFile" && \
        exiftool -q -overwrite_original -FileModifyDate="$ptt" "$newFile" && \
        rm "$f"
      fi
    fi
  done

  echo "total files processed: $count"
}

checkIfInstalled() {
  if /usr/bin/which -s "$1"; then
    return 1;
  else
    echo "$1 not found. install $2 to continue.";
    return 0;
  fi
}

checkIfInstalled "ffmpeg" "ffmpeg" && exit;
checkIfInstalled "exiftool" "exiftool" && exit;
checkIfInstalled "magick" "imagemagick" && exit;
checkIfInstalled "gdate" "coreutils on Mac or make an executable of 'gdate' in the path based on 'date' on Linux" && exit;

case "$1" in
  "") printUsage;;
  get-json) getJsonPath "$2";;
  sanitize-all) sanitizeAll;;
esac
