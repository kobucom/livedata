#!/usr/bin/perl

package SqlTable;
use parent Table;

# SqlTable.pm - table access methods; calls DbiStore.pm
# 20-may-25
# 20-may-26 tested
# 20-may-31 multiple and arbitrary primary keys
# 20-jul-14 made subclass of AbsTable.pm
# 20-aug-10 Table.pm -> bind_params version -> SqlTable.pm
# 20-aug-10 previous no-params version saved as SqlTableNP.pm
# 20-aug-10 rejectBadKey
# 20-aug-23 no more rejectBadKey
# 20-aug-23 check for empty primary key value
#
# anti-injection measures:
# - app-side
#   - reject bad keys
# - dbi-side
#   - $dbh->quote(value) - for non-param case
#   - @bind_values - param case - this is used

use strict;
use warnings;

use lib "$ENV{PREPRO_DATA}";
use DbiStore;
use Logger;
use Util;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# constructor($name, $store)
sub new {
    my ($class, $name, $store) = @_;
    my $self = $class->SUPER::new($name); # table name
    $self->{store} = $store; # dbi instance
    $self->{cols} = $store->getColumns($name); # all column names
    $self->{pkeys} = $store->getKeys($name); # primary key(s)
    $self->{nkeys} = Util::subtractArrary($self->{cols}, $self->{pkeys}); # non-key columns
    # DbiStore's logger reused by any instance of SqlTable
    $self->{store}->{logger}->trace("Table->new: nkeys: @{$self->{nkeys}}");
    return bless $self, $class;
}

# rejectBadKey($key)
# anti-attack measure for a key
# make sure the key does not include dangerous characters: such as
# space, quote, double-quote, parens or semicolon
# die if it does
# Note: however, this function is never called because keys and columns not defined
# in the table does not reach here any way.
sub rejectBadKey {
    my $key = shift;
    if ($key !~ /^\w+$/) { die "Bad column name: $key"; }
}

# [internal utility instance method]
# ($where_clause, \@params) = $table->whereClause($hash_ref)
# $hash_ref - one or more key-value pairs, eg. { customer => 'suzuki' }
# returns ('customer = ?', ['suzuki'])
sub whereClause {
    my ($self, $hash_ref) = @_;
    my %hash = %{$hash_ref};
    my $wc = '';
    my $first = true;
    my @params = ();
    for my $k (keys %hash) {
        #rejectBadKey($k);
        $wc .= $first ? "$k = ?" : " and $k = ?";
        $first = false;
        push(@params, $hash{$k});
    }
    return ($wc, \@params);
}

# $bool = getRows($callback)
# callback($hash_ref)
# pass every row in the table
sub getRows {
    my ($self, $callback) = @_;
    my $sql = "select * from $self->{name}";
    return $self->{store}->selectTable($sql, $callback);
}

# $bool = getRow($id_hash_ref, $callback)
# callback($row_hash_ref)
# pass a row in a table matching the id
sub getRow {
    my ($self, $id_hash_ref, $callback) = @_;
    my ($wc, $params_ref) = $self->whereClause($id_hash_ref);
    my $sql = "select * from $self->{name} where " . $wc;
    return $self->{store}->selectTable($sql, $callback, $params_ref);
}

# $bool = addRow($hash_ref)
# $hash_ref should contain all key-value pairs: id and others
sub addRow {
    my ($self, $row_ref) = @_;
    my %row = %{$row_ref};
    my $keys = '';
    my $vals = '';
    my @params = ();
    my $first = true;
    for my $k (keys %row) {
        #rejectBadKey($k);
        if (grep(/^$k$/, @{$self->{pkeys}}) && !$row{$k}) {
            die "Empty value for primary key: $k";
        }
        $keys .= $first ? "$k" : ",$k";
        $vals .= $first ? '?' : ',?';
        $first = false;
        push(@params, $row{$k});
    }
    my $sql = "insert into $self->{name} ($keys) values ($vals)";
    return $self->{store}->updateTable($sql, \@params);
}

# $bool = updateRow($id_hash_ref, $rest_hash_ref)
# $id_hash_ref - primary key-value pairs.
# $rest_hash_ref contains key-value pairs to be updated; id should be excluded
sub updateRow {
    my ($self, $id_hash_ref, $rest_hash_ref) = @_;
    my %hash = %{$rest_hash_ref};
    my $keysVals = '';
    my @params = ();
    my $first = true;
    for my $k (keys %hash) {
        #rejectBadKey($k);
        $keysVals .= $first ? "$k=?" : ",$k=?";
        $first = false;
        push(@params, $hash{$k});
    }
    my ($wc, $where_params_ref) = $self->whereClause($id_hash_ref);
    my $sql = "update $self->{name} set $keysVals where " . $wc;
    push(@params, @{$where_params_ref});
    return $self->{store}->updateTable($sql, \@params);
}

# $bool = deleteRow($id_hash_ref)
# $id_hash_ref - hash of primary key-value pairs
sub deleteRow {
    my ($self, $id_hash_ref) = @_;
    my ($wc, $params_ref) = $self->whereClause($id_hash_ref);
    my $sql = "delete from $self->{name} where " . $wc;
    return $self->{store}->updateTable($sql, $params_ref);
}

true; # need to end with a true value
