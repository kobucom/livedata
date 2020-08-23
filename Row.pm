#!/usr/bin/perl

package Row;

# Row.pm - passive row instance used as a convenience place holder
# - hash can be turned into a row instance
# - row instance can be used as a hash
# 20-may-25

use strict;
use warnings;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# constructor($table, $hash_ref)
sub new {
    my ($class, $hash_ref) = @_;
    return bless $hash_ref, $class;
}

1; # need to end with a true value
