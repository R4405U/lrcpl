#!/bin/env perl

use v5.36;
use Getopt::Long;
use Image::ExifTool;
use LWP::UserAgent;
use JSON;
use URI::Escape;
use File::Basename;
use File::Spec;
use File::Find;


#Today: 11/01/2026 Sunday

=doc
Usage: lrc.pl [options]
  Options:
      --file <path>    Download lyrics for a single music file
      --dir  <path>    Download lyrics for all music files in a folder
      --force          Force download lyrics even if it already exists
      --help           Show this help message
      --info           Print script info
=cut

my $PROJ_VERSION  = "0.1.0";
my $PROJ_NAME     = "lrcpl";
my $PROJ_URL      = "https://github.com/R4405U/lrcpl.git";

sub help{
    return qq{Usage: $0 [options]
    Options:
        --file <path>    Download lyrics for a single music file
        --dir  <path>    Download lyrics for all music files in a folder
        --force          Force download lyrics even if it already exists
        --help           Show this help message
        --info           Print script info
    }
}

sub write_lyrics($lrc_path, $content){

    open(my $fd, ">:encoding(UTF-8)", $lrc_path)
      or die "Could not open '$lrc_path' for writing: $!";

    print $fd $content;
    close($fd);
    say "Successfully saved lyrics to: $lrc_path"

}

sub fetch_metadata($path){
    my $et        = Image::ExifTool->new;

    my $info      = $et->ImageInfo($path);

    my $artist    = $info->{Artist} // $info->{Author} // "Unknown";
    my $title     = $info->{Title}  // "Unknown";
    my $album     = $info->{Album} // "Unknown"; 
    my $raw_dur   = $info->{Duration} // 0;
    my $duration   = 0;
    
if ($raw_dur =~ /^(?:(?:(\d+):)?(\d+):)?(\d+(?:\.\d+)?)$/) {
        $duration = ($1 // 0) * 3600 + ($2 // 0) * 60 + ($3 // 0);
    } else {
        $raw_dur =~ s/[^\d\.]//g;
        $duration = $raw_dur || 0;
    }
    return ($artist,$title,$album,$duration);
}

sub get_by_file($ua,$path, $is_forced){
    if (! -f $path){
        warn "File not found: $path\n";
        die help();
    }

    my ($name, $file_path, $suffix) = fileparse($path, qr/\.[^.]*$/);
    my $lrc_path = File::Spec->catfile($file_path,"$name.lrc");

    if(-e $lrc_path && !$is_forced){
      say "Skipping: Lyrics already exist for $path";
      return;
    }

    my ($artist,$title,$album,$duration) = fetch_metadata($path);

    # TODO: Fallback if tags are missing;

    say "\n\nFetching lyrics for: ";
    say "Artist: $artist";
    say "Title:  $title";
    say "Album:  $album";
    say "Duration: ",int($duration), "\n\n";

    my $url = sprintf(
      "https://lrclib.net/api/get?artist_name=%s&track_name=%s&album_name=%s&duration=%d",
      uri_escape($artist),
      uri_escape($title),
      uri_escape($album),
      int($duration)
    );


    
    say "Fetching url: $url";
    
    my $response = $ua->get($url, "Accept" => "application/json");

    if($response->is_success){
      my $content = decode_json($response->decoded_content);
      my $synced_lyrics = $content->{syncedLyrics};
      my $plain_lyrics  = $content->{plainLyrics};
      my $instrumental  = $content->{instrumental};

      if($synced_lyrics){
        say "Found synced lyrics";
        write_lyrics($lrc_path,$synced_lyrics);
      }
      elsif($plain_lyrics){
        say "Found plain lyrics";
        write_lyrics($lrc_path,$plain_lyrics);
      }
      elsif($instrumental){
        say "Instrumental music, no lyrics available";
      }
      else{
        warn "No lyrics found";
        return;
      }
    }
    else{
      if ($response->code == 408 || $response->message =~ /timeout/i) {
          warn "Skipping: Request timed out for $title\n";
      }
      else {
          warn "Skipping: HTTP Error " . $response->status_line . " for '$title'\n";
      }
      return; # Move to the next file in the loop instead of crashing}
    }

}
sub get_by_dir($ua,$path,$is_forced){
  
    find(sub {
        return unless -f $_ && /\.(mp3|flac|m4a|ogg|wav)$/i;
        get_by_file($ua,$File::Find::name, $is_forced);
      },$path);





    # opendir(my $dh, $path) or die "Can't open $path: $!";
    # while (my $entry = readdir($dh)){
    #     next if $entry =~ /^\./;
    #     next unless $entry =~ /\.(mp3|flac|m4a)$/i;
    #     get_by_file($ua,"$path/$entry",$is_forced);
    # }
    # closedir($dh);
}



sub main{
    my %opts;
    GetOptions(
        "file=s"  =>    \$opts{filepath},
        "dir=s"   =>    \$opts{dir},
        "help"    =>    \$opts{help},
        "info"    =>    \$opts{info},
        "force"   =>    \$opts{force}
    ) or die help();

    my $header = sprintf(
      "%s v%s (%s)",
      $PROJ_NAME,
      $PROJ_VERSION,
      $PROJ_URL
    );
    my $ua = LWP::UserAgent->new(
      "timeout" => 30,
      "agent"   => $header,
    );
    if ($opts{filepath} && $opts{dir}) {
        die "Error: Please provide either --file OR --dir, not both at once.\n";
    }

    if (!$opts{filepath} && !$opts{dir} && !$opts{help} && !$opts{info}) {
        die "Error: You must provide either --file or --dir.\nTry --help for more information.\n";
    }



    if($opts{help}){
        say help();
    }
    elsif($opts{info}){
      say "$PROJ_NAME\nv$PROJ_VERSION\n$PROJ_URL";
    }
    elsif($opts{filepath}){
        get_by_file($ua,$opts{filepath},$opts{force});
    }
    elsif($opts{dir}){
        get_by_dir($ua,$opts{dir}, $opts{force});
    }
}


main();

