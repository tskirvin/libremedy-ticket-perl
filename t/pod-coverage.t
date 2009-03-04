#!/usr/bin/perl
# $Id: pod-coverage.t 4612 2008-08-15 19:44:24Z tskirvin $
#
# t/pod-coverage.t - test pod coverage
#
# Taken from Test::Pod::Coverage's man page

use Test::More;
eval "use Test::Pod::Coverage 1.00";
if ($@) { 
    print "1..1\n";
    print "ok 1 # skip - Test::Pod::Coverage 1.00 required for testing POD\n";
    exit;
}
all_pod_coverage_ok(
    { trustme => [ qw/new/ ] }
);
