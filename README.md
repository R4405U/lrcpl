!> [!WARNING]
> --verbose, -v, -vv is not fully developed, restrain from using it.

# lrc.pl
Perl script to fetch and download lyrics from [LRCLIB](https://lrclib.net/) using [LRCLIB API](https://lrclib.net/docs)

[![Demo](demo.gif)]()




Today:   11/01/2026 Sunday

# Requirements
Getopt::Long  
Image::ExifTool  
LWP::UserAgent  
LWP::Protocol:https  
JSON  
URI::Escape  

You can install all these using given below command

```bash
cpanm --installdeps .
```

or via your system package manager


# Help
```
Usage: lrc.pl [options]  
  Options:
      -f, --file            <path>    Download lyrics for a specific music file.
      -d, --dir             <path>    Scan a directory and download lyrics for all music files inside.
      -v, -vv, --verbose              Show detailed debug information.
      --force                         Overwrite existing .lrc files.
      -h, --help                      Show this help message.
      -i, --info                      Print script info.
```

## Example

```bash
perl -d "~/Music/"
```

# TODO:
[ ] Stabilize --verbose logging.
[ ] colored output  
[ ] fallback /api/search  
[ ] make code readable  
[x] implement progress bar  





