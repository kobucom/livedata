#!/usr/bin/perl

package SqlTable;

# SqlTable.pm - table access methods; calls DbiStore.pm
# 20-may-25
# 20-may-26 tested
# 20-may-31 multiple and arbitrary primary keys
# 20-aug-10 backport: bind_params
#
# anti-injection measures:
# - app-side
#   - reject bad keys
# - dbi-side
#   - $dbh->quote(value) - for non-param case
#   - @bind_values - param case - this is used

use strict;
use warnings;

use lib "$ENV{PREPRODIR}";
use Logger;
use DbiStore;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# constructor($name, $store)
sub new {
    my ($class, $name, $store) = @_;
    my $logger = new Logger($ENV{DEBUG_LEVEL});
    my $cols = $store->getColumns($name);
    my $pkeys = $store->getKeys($name);
    my $nkeys = subtractArrary($cols, $pkeys);
    $logger->trace("Table->new: nkeys: @{$nkeys}");
    return bless {
        store => $store, # dbi instance
        name => $name,   # table name
        logger => $logger,
        cols => $cols,   # all column names
        pkeys => $pkeys, # primary key(s)
        nkeys => $nkeys, # non-key columns
    }, $class;
}

# \@rest = subtractArrary(\@all, \@some)
# remove elements in 'some' from 'all'
sub subtractArrary {
    my ($all_ref, $some_ref) = @_; 
    my @all = @{$all_ref};
    my @some = @{$some_ref};
    my %hash;
    @hash{@all} = ();
    delete @hash{@some};
    my @rest = keys %hash;
    return \@rest;
}

# rejectBadKey($key)
# die if the key includes space, quote or double-quote
sub rejectBadKey {
    my $key = shift;
    if ($key =~ /[ '"]/) { die "Bad column name: $key"; } # anti-attack
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
        rejectBadKey($k);
        $wc .= $first ? "$k = ?" : " and $k = ?";
        $first = false;
        push(@params, $hash{$k});
    }
    return ($wc, \@params)
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
        # Can't use an undefined value as a HASH reference at /usr/local/prepro/Table.pm line 87, line 1. 
        # on clicking Reset then Add without filling data
    my $keys = '';
    my $vals = '';
    my @params = ();
    my $first = true;
    for my $k (keys %row) {
        rejectBadKey($k);
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
        rejectBadKey($k);
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

1; # need to end with a true value
