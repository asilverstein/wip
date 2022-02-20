find . -name "*.bz2" | while read filename; do bunzip2 "$filename"; done;
