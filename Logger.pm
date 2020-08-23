#!/usr/bin/perl

# Logger used by Embedder.pm
# when running under apache, output to STDERR goes to apache error.log.
# STDOUT goes to web browser. that's why pretty everything Logger outputs
# goes to STDERR, except inline() which inserts log within STDOUT. 
#
# STDERR - error, warn, log, debug
# STDOUT - inline
#
# 20-may-27

package Logger;

use strict;
use warnings;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# constructor($level)
# level - 0: no debug output, 1: 'debug' to stderr, 2: 'trace' to stdout, 'inline' to stdout 
sub new {
    my ($class, $level) = @_;
    return bless { level => $level }, $class;
}

sub error {
    my ($self, $msg) = @_;
    print STDERR "[ERROR] " . $msg . "\n";
}

sub warn {
    my ($self, $msg) = @_;
    print STDERR "[WARN] " . $msg . "\n";
}

sub log {
    my ($self, $msg) = @_;
    print STDERR "[INFO] " . $msg . "\n";
}

sub debug {
    my ($self, $msg) = @_;
    if ($self->{level} > 0) { print STDERR "[DEBUG] " . $msg . "\n"; }
}

sub trace {
    my ($self, $msg) = @_;
    if ($self->{level} > 1) { print STDERR "[TRACE] " . $msg . "\n"; }
}

# traces intermixed into STDOUT
sub inline {
    my ($self, $msg) = @_;
    if ($self->{level} > 1) { print STDOUT "<<< " . $msg . " >>>\n"; }
}

true; # need to end with a true value
