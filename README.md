# lrc.pl
perl script to fetch lyrics from LRCLIB using LRCLIB API

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

or you can install using your native distro package manager


# Help
Usage: lrc.pl [options]  
  Options:  
      --file <path>    Download lyrics for a single music file  
      --dir  <path>    Download lyrics for all music files in a folder  
      --force          Force download lyrics even if it already exists  
      --help           Show this help message  
      --info           Print script info  


# TODO:
[ ] make code readable  
[ ] colored output  
[ ] --verbose option  


