# google-photos-takeout-cleaner
A script that cleans up Google Photos Takeout data to make them ready to be imported into Apple Photos

# Usage
Run the following command in the directory where unpacked google photo takeout photos/videos are in:

`% ./gpt-clean sanitize-all`

The script will scan through all photos and videos in your current directory and perform the following:
- Convert erroneous pngs and jpegs back to their intended formats
- For photos missing EXIF DateTimeOriginal attribute, insert them via Google Photo json file's photoTakenTime
- Convert video MTS files, which apple photos doesn't import, into mp4 files
