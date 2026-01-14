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
      -f, --file            <path>    Download lyrics for a specific music file
      -d, --dir             <path>    Scan a directory and download lyrics for all music files inside
      -v, -vv, --verbose              Show detailed debug information
      --force                         Overwrite existing .lrc files
      -h, --help                      Show this help message
      -i, --info                      Print script info
=cut

$| = 1;
my $PROJ_VERSION = "0.1.0";
my $PROJ_NAME    = "lrcpl";
my $PROJ_URL     = "https://github.com/R4405U/lrcpl.git";
my %messages;

sub help {
    return qq{Usage: $0 [options]
  Options:
      -f, --file            <path>    Download lyrics for a specific music file
      -d, --dir             <path>    Scan a directory and download lyrics for all music files inside
      -v, -vv, --verbose              Show detailed debug information
      --force                         Overwrite existing .lrc files
      -h, --help                      Show this help message
      -i, --info                      Print script info
    }
}

sub write_lyrics( $lrc_path, $content ) {

    open( my $fd, ">:encoding(UTF-8)", $lrc_path )
        or die "Could not open '$lrc_path' for writing: $!";

    print $fd $content;
    close($fd);

    # say "Successfully saved lyrics to: $lrc_path\n";

}

sub fetch_metadata($path) {
    my $et = Image::ExifTool->new;

    my $info = $et->ImageInfo($path);

    my $artist   = $info->{Artist}   // $info->{Author} // "Unknown";
    my $title    = $info->{Title}    // "Unknown";
    my $album    = $info->{Album}    // "Unknown";
    my $raw_dur  = $info->{Duration} // 0;
    my $duration = 0;

    if ( $raw_dur =~ /^(?:(?:(\d+):)?(\d+):)?(\d+(?:\.\d+)?)$/ ) {
        $duration = ( $1 // 0 ) * 3600 + ( $2 // 0 ) * 60 + ( $3 // 0 );
    }
    else {
        $raw_dur =~ s/[^\d\.]//g;
        $duration = $raw_dur || 0;
    }
    return ( $artist, $title, $album, $duration );
}

sub progress_bar( $file_no, $count ) {

    my $percent  = ( $file_no / $count ) * 100;
    my $bar_size = 30;
    my $filled   = int( $file_no / $count * $bar_size );
    my $bar      = ( ":" x $filled ) . ( "-" x ( $bar_size - $filled ) );

    printf( "\rProcessing: [%s] %d%% (%d/%d)",
        $bar, $percent, $file_no, $count );
}

sub get_by_file( $ua, $path, $is_forced, $verbose ) {

    return do { say "File not found: $path\n"; 0 } if !-f $path;


    my ( $name, $file_path, $suffix ) = fileparse( $path, qr/\.[^.]*$/ );
    my $lrc_path = File::Spec->catfile( $file_path, "$name.lrc" );

    if ( -e $lrc_path && !$is_forced ) {
        say "Skipping: Lyrics already exist for $path" if ( $verbose > 0 );
        return;
    }

    # say $path;

    my ( $artist, $title, $album, $duration ) = fetch_metadata($path);

    # TODO: Fallback if tags are missing;

    if ($verbose) {
        say "\n\nFetching lyrics for: ";
        say "Artist: $artist";
        say "Title:  $title";
        say "Album:  $album";
        say "Duration: ", int($duration), "\n\n";
    }

    my $url = sprintf(
        "https://lrclib.net/api/get?artist_name=%s&track_name=%s&album_name=%s&duration=%d",
        uri_escape($artist), uri_escape($title),
        uri_escape($album),  int($duration)
    );

    say "Fetching url: $url" if ( $verbose > 0 );

    my $response = $ua->get( $url, "Accept" => "application/json" );

    if ( $response->is_success ) {
        my $content       = decode_json( $response->decoded_content );
        my $synced_lyrics = $content->{syncedLyrics};
        my $plain_lyrics  = $content->{plainLyrics};
        my $instrumental  = $content->{instrumental};

        if ($synced_lyrics) {
            say "Found synced lyrics" if ( $verbose > 0 );
            write_lyrics( $lrc_path, $synced_lyrics );
        }
        elsif ($plain_lyrics) {
            say "Found plain lyrics" if ( $verbose > 0 );
            write_lyrics( $lrc_path, $plain_lyrics );
        }
        elsif ($instrumental) {
            my $message = "Instrumental music, no lyrics available";
            $messages{sprintf "$artist - $title"} = $message;
            say $message if ( $verbose > 0 );
        }
        else {
            my $message = "No lyrics found";
            $messages{sprintf "$artist - $title"} = $message;
            warn $message if ( $verbose > 0 );
            return;
        }
    }
    else {
        if ( $response->code == 408 || $response->message =~ /timeout/i ) {
            my $message = "Skipping: Request timed out for '$artist - $title'\n";
            $messages{sprintf "$artist - $title"} = $message;
            warn $message if ($verbose > 0);
        }
        else {
            my $message = "Skipping: HTTP Error "
                . $response->status_line
                . " for '$artist - $title'\n";
            $messages{sprintf "$artist - $title"} = $message;
            warn $message if ($verbose > 0);
            return;    # Move to the next file in the loop instead of crashing}
    }
}
}

sub get_by_dir( $ua, $path, $is_forced, $v_level ) {
    my @files;
    say "Scanning directory '$path'..." if $v_level == 3;
    find(
        sub {
            push @files, $File::Find::name
                if -f $_ && /\.(mp3|flac|m4a|ogg|wav)$/i;
        },
        $path
    );

    my $total = scalar @files;

    do { say "No music files found in $path"; return; } if ( $total == 0 );
    say "Downloading lyrics for $total songs\n";

    for ( 1 .. $total ) {
        my $file = $files[ $_ - 1 ];
        progress_bar( $_, $total ) if $v_level == 0;
        get_by_file( $ua, $file, $is_forced, $v_level );
    }
    say "\nDone!\n";

    say "$_: $messages{$_}" for (keys(%messages));
}

sub main {
    my %opts = ( verbose => 0, );
    Getopt::Long::Configure("bundling");
    GetOptions(
        "file|f=s"   => \$opts{filepath},
        "dir|d=s"    => \$opts{dir},
        "help|h"     => \$opts{help},
        "info|i"     => \$opts{info},
        "verbose|v+" => \$opts{verbose},
        "force"      => \$opts{force}
    ) or die help();

    my $header
        = sprintf( "%s v%s (%s)", $PROJ_NAME, $PROJ_VERSION, $PROJ_URL );
    my $ua = LWP::UserAgent->new(
        "timeout" => 30,
        "agent"   => $header,
    );
    if ( $opts{filepath} && $opts{dir} ) {
        die
            "Error: Please provide either --file OR --dir, not both at once.\n";
    }

    if ( !$opts{filepath} && !$opts{dir} && !$opts{help} && !$opts{info} ) {
        die
            "Error: You must provide either --file or --dir.\nTry --help for more information.\n";
    }

    if ( $opts{help} ) {
        say help();
    }
    elsif ( $opts{info} ) {
        say "$PROJ_NAME\nv$PROJ_VERSION\n$PROJ_URL";
    }
    elsif ( $opts{filepath} ) {
        get_by_file( $ua, $opts{filepath}, $opts{force}, 1 );
    }
    elsif ( $opts{dir} ) {
        get_by_dir( $ua, $opts{dir}, $opts{force}, $opts{verbose} );
    }
}

main();

