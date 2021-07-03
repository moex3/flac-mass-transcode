#!/usr/bin/env perl
use strict;
use warnings;
use File::Path;
use Getopt::Long;
use File::Copy qw(copy);

# TODO check if the dependencies are present, and error if not

## Parse arguments

my $updir = 0;
my $help = 0;
my $forcecover;
GetOptions(
	"help" => \$help,
	"updir=i" => \$updir,
	"cover=s" => \$forcecover)
or die("Error in command line options");

if ($help) {
	help();
}

if (scalar @ARGV != 2) {
	print("Bad arguments\n");
	usage();
}
my ($IDIR, $ODIR) = @ARGV;

my @flacMapPaths = mapInputToOutput($IDIR, $ODIR, q(*.flac));
my $sizeLength = scalar @flacMapPaths != 0 ? int(log(scalar @flacMapPaths / 2)/log(10)) : 0;

## Transcode here
for (my $i = 0; $i < @flacMapPaths; $i += 2) {
	my $inp = $flacMapPaths[$i  ];
	my $out = $flacMapPaths[$i+1];
	$out =~ s/\.flac$/.opus/;
	next if (-e $out);
	File::Path::make_path(dirname($out));
	my $inpPretty = $inp;
	my $outPretty = $out;
	$inp =~ s!'!'\\''!g;
	$out =~ s!'!'\\''!g;
	my $coverOpts = "";
	my $cover = $forcecover;
	if ($cover || (!hasImage($inp) && defined($cover = getcover($inp)))) {
		print("## Adding cover $cover ##\n");
		$cover =~ s!'!'\\''!g;
		$coverOpts .= qq(--picture '$cover');
	}
	printf("[%0*d/%d] %s -> %s\n", $sizeLength, $i/2+1, @flacMapPaths / 2, $inpPretty, $outPretty);
	`opusenc --music --comp 10 $coverOpts -- '$inp' '$out'`;
}

print("## Starting copying files ##\n");
my @plainMapPaths = mapInputToOutput($IDIR, $ODIR, "*.mp3' -o -iname '*.m4a' -o -iname '*.ogg' -o -iname '*.opus");
$sizeLength = scalar @plainMapPaths != 0 ? int(log(scalar @plainMapPaths / 2)/log(10)) : 0;

## Just copy here
for (my $i = 0; $i < @plainMapPaths; $i += 2) {
	my $inp = $plainMapPaths[$i  ];
	my $out = $plainMapPaths[$i+1];
	next if (-e $out);
	# TODO? Add covers to these too? Naaah
	File::Path::make_path(dirname($out));
	printf("[%0*d/%d] %s -> %s\n", $sizeLength, $i/2+1, @plainMapPaths / 2, $inp, $out);
	copy($inp, $out);
}

print("\n## Conversion done! ##\n");
exit(0);

###############################################################################
###############################################################################

## Return a list of string pairs that maps like this:
##  original file name, output file name ...
## Args:
##  1) input  directory
##  2) output directory
##  3) iname option for find
sub mapInputToOutput {
	my $inpDir = shift;
	my $outDir = shift;
	my $fglob  = shift;

	## Get the path of every file in the given directory, and below it
	my @files = qx(find "$inpDir" -type f -iname '$fglob');
	## Get directories where files are located
	my @dirs;
	foreach my $file (@files) {
		#$file =~ s/\R//;
		chomp($file);
		my $found = 0;
		my $dirn = dirname($file);
		foreach my $dir (@dirs) {
			if ($dir eq $dirn) {
				$found = 1;
				last;
			}
		}
		if (!$found) {
			push(@dirs, $dirn);
		}
	}

	my @splitInpDir = split("/", $inpDir);
	my @plusDirs = @splitInpDir[scalar @splitInpDir - $updir..scalar @splitInpDir - 1];
	my $outpath = "$outDir/" . join("/", @plusDirs);

	my @result;
	foreach my $file (@files) {
		chomp($file);
		my $outfname = "$outpath/" . substr($file, length $inpDir);
		my $inp = qq($file);
		my $out = qq($outfname);
		push(@result, $file);
		push(@result, $outfname);
	}
	return @result;
}

## Easy, just print how to use
sub usage {
	print("Usage: $0 [-h | --help] [-u | --uplevel NUM] [-c | --cover IMG] <input_dir> <output_dir>\n");
	exit 1;
}

sub help {
	my $h = <<EOF;
Usage:
	flac-mass-transcode.pl [options] <input_dir> <output_dir>
	
	-h, --help            print this help text
	-u, --uplevel  NUM    take this number of directories from the input path
	-c, --cover    IMG    add this image as an album cover
EOF
	print("$h");
	exit 0;
}

## Get the directory of the file
## /a/b/c.flac -> /a/b
sub dirname {
	my $str = shift;
	my $ind = rindex($str, '/');
	return substr($str, 0, $ind);
}

## Search for a cover image in the given path
sub getcover {
	my $flacpath = shift;
	my $dir = dirname($flacpath);
	my $regex = "\\(thumb\\|albumartwork\\|cover\\|folder\\)\\.\\(pn\\|jp\\)g\$";
	my $cmd = "find '$dir' -maxdepth 20 -type f -iregex '.*/$regex'";
	my @imgs = split(/\n/, `$cmd`);
	return undef if scalar(@imgs) == 0;
	return $imgs[0];
}

## Checks if a flac file has a cover embedded or not
sub hasImage {
	my $flacpath = shift;
	my $fname = qq($flacpath);
	my $lines = `metaflac --list --block-type=PICTURE '$fname' | wc -l`;
	return $lines != 0;
}
