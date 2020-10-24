#!/usr/bin/perl

# Logger used by Embedder.pm
# when running under apache, output to STDERR goes to apache error.log.
# STDOUT goes to web browser. that's why pretty everything Logger outputs
# goes to STDERR, except inline() which inserts log within STDOUT. 
#
# 20-may-27
# 20-aug-04 debugString
# 20-oct-19 no more DL_MARKDOWN, DL_INTERACTIVE

package Logger;

use strict;
use warnings;
use utf8;

use lib "$ENV{PREPRO_DATA}";
use Util;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# debug level
use constant { DL_NONE => 0, DL_DEBUG => 1, DL_TRACE => 2, DL_INLINE => 3 };

# 0: info/warn/error only
# 1: debug and debugString
# 2: trace
# 3: inline
# * all log output goes to stderr except 'inline'

# [class, utility] $level = debugLevel()
sub debugLevel {
    return $ENV{DEBUG_LEVEL} // DL_NONE;
}

# constructor
sub new {
    my $class = shift;
    return bless { debug_level => debugLevel() }, $class;
}

sub error {
    my ($self, $msg) = @_;
    print STDERR Util::dateTime() . " [ERROR] " . $msg . "\n";
}

sub warn {
    my ($self, $msg) = @_;
    print STDERR Util::dateTime() . " [WARN] " . $msg . "\n";
}

sub log {
    my ($self, $msg) = @_;
    print STDERR Util::dateTime() . " [INFO] " . $msg . "\n";
}

sub debug {
    my ($self, $msg) = @_;
    if ($self->{debug_level} >= DL_DEBUG) { print STDERR "[DEBUG] " . $msg . "\n"; }
}

sub trace {
    my ($self, $msg) = @_;
    if ($self->{debug_level} >= DL_TRACE) { print STDERR "[TRACE] " . $msg . "\n"; }
}

# traces intermixed into STDOUT - local debug only, breaks html output
sub inline {
    my ($self, $msg) = @_;
    if ($self->{debug_level} >= DL_INLINE) { print STDOUT "<<< " . $msg . " >>>\n"; }
}

# debugString($title, $str) prints
# title: str (u|-) hex
sub debugString {
    my ($self, $title, $str) = @_;
    if ($self->{debug_level} >= DL_DEBUG) {
        my $h = join('', map { my $c = ord; $c < 32 || $c > 126 ? sprintf('`%x', $c) : $_; } split(//, $str) );
        print STDERR "[DEBUG_STRING] $title: '$str' " . (utf8::is_utf8($str) ? 'u' : '-') . " '$h'\n";
    }
}

true; # need to end with a true value
