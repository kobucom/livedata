#!/usr/bin/perl

package Table;

# Table.pm - super class for SqlTable.pm and other virtual tables
# 20-jul-13 
# 20-aug-10 renamed from AbsTable.pm

use strict;
use warnings;

# constants
use constant { true => 1, false => 0 };

# constructor($name)
sub new {
    my ($class, $name) = @_;
    return bless {
        name => $name # table name
    }, $class;
}

# $bool = getRows($callback)
# callback($hash_ref)
# pass every row in the table
sub getRows {
    my ($self, $callback) = @_;
    return false;
}

# $bool = getRow($id_hash_ref, $callback)
# callback($row_hash_ref)
# pass a row in a table matching the id
sub getRow {
    my ($self, $id_hash_ref, $callback) = @_;
    return false;
}

# $bool = addRow($hash_ref)
# $hash_ref should contain all key-value pairs: id and others
sub addRow {
    my ($self, $row_ref) = @_;
    return false;
}

# $bool = updateRow($id_hash_ref, $rest_hash_ref)
# $id_hash_ref - primary key-value pairs.
# $rest_hash_ref contains key-value pairs to be updated; id should be excluded
sub updateRow {
    my ($self, $id_hash_ref, $rest_hash_ref) = @_;
    return false;
}

# $bool = deleteRow($id_hash_ref)
# $id_hash_ref - hash of primary key-value pairs
sub deleteRow {
    my ($self, $id_hash_ref) = @_;
    return false;
}

true; # need to end with a true value
