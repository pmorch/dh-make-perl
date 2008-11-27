#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More 'no_plan';

use FindBin qw($Bin);
use File::Touch qw(touch);

require "$Bin/../dh-make-perl";        # Load our code for testing.

unlink("$Bin/Contents.cache");

sub instance
{
    AptContents->new({
        homedir => $Bin,
        contents_dir    => "$Bin/contents",
        verbose => 0,
        sources_file    => "$Bin/contents/sources.list",
        @_,
    });
}

eval { AptContents->new() };
ok( $@, 'AptContents->new with no homedir dies' );
like( $@, qr/No homedir given/, 'should say why it died' );

my $apt_contents = instance( contents_dir => 'non-existent' );

is( $apt_contents, undef, 'should not create with no contents' );


$apt_contents = instance();

isnt( $apt_contents, undef, 'object created' );

is_deeply(
    $apt_contents->contents_files,
    [ sort glob "$Bin/contents/*Contents*" ],
    'contents in a dir'
);

ok( -f "$Bin/Contents.cache", 'Contents.cache created' );

is( $apt_contents->source, 'parsed files', 'no cache was used' );

$apt_contents = instance();

is( $apt_contents->source, 'cache', 'cache was used' );

sleep(1);   # allow the clock to tick so the timestamp actually differs
touch( glob "$Bin/contents/*Contents*" );

$apt_contents = instance();

is( $apt_contents->source, 'parsed files', 'cache updated' );

is_deeply(
    [ $apt_contents->find_file_packages('Moose.pm')],
    [ 'libmoose-perl' ],
    'Moose found by find_file_packages' );

is( $apt_contents->find_perl_module_package('Moose'), 'libmoose-perl', 'Moose fund by module name' );

ok( unlink "$Bin/Contents.cache", 'Contents.cache unlnked' );
