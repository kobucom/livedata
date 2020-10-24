# DbiStore.pm - sqlite3 via DBI interface (called from SqlTable.pm)
# 20-may-25 test-dbi.pl
# 20-may-26 tested from Table.pm
# 20-may-30 primary keys
# 20-may-31 column names
# 20-aug-09 fetchrow_array() -> fetchrow_hashref()
# 20-aug-09 bind_values supported (sql-only case still usable)

package DbiStore;

use strict;
use warnings;

use Data::Dumper qw(Dumper);
use DBI;

#use Data::Dump qw(dump);
  # not standard

use lib "$ENV{PREPRO_DATA}";
use Logger;

use constant { true => 1, false => 0 };

# constructor($dbpath)
sub new {
    my ($class, $dbpath) = @_;
    return bless {
        dbpath => $dbpath, # '/var/www/dav/bluff/data/bluff.db'
        logger => new Logger(), # per-store logger
        dbh => undef
    }, $class;
}

# [instance method] openStore()
# die on error
sub openStore {
    my $self = shift;
    my $driver   = "SQLite"; 
    my $database = $self->{dbpath};
    my $dsn = "dbi:$driver:dbname=$database"; # '' -> $ENV{DBI_DSN}
    my $userid = undef; # '' -> $ENV{DBI_USER}
    my $password = undef; # '' -> $ENV{DBI_PASS}
    $self->{dbh} = DBI->connect($dsn, $userid, $password,
        { RaiseError => 0, AutoCommit => 1 }) 
            or die "openStore: $DBI::errstr";
        # returns undef on error
        # Note: PrintError and PrintWarn defaults to 1
        # Note: RaiseWarn not recognized on sakura5 while wsl OK 
}

# $bool = selectTable($sql, $callback, [\@bind_values])
# callback($hash_ref)
sub selectTable {
    my ($self, $sql, $callback, $bindArray_ref) = @_;
    my $logger = $self->{logger};
    $logger->debug("selectTable: '$sql'");
    if ($bindArray_ref) { $logger->debug(Dumper($bindArray_ref)); }
    if (!$self->{dbh}) {
        $logger->error("selectTable: database not open"); # assert
        return false;
    }
    my $sth = $self->{dbh}->prepare($sql);
    my $rv = defined($bindArray_ref) ? $sth->execute(@{$bindArray_ref}) : $sth->execute();
    # execute() returns undef on error otherwise # of rows or -1 if unknown
    if(!defined($rv)) {
        $logger->error("selectTable: rv = $rv, err = $DBI::err, errstr = $DBI::errstr");
        return false;
    }

    # pass each row to callback 
    my $hash_ref;
    while(defined($hash_ref = $sth->fetchrow_hashref())) {
        $callback->($hash_ref);
        # value is undef if null
        # $hash_ref reused on next fetch
    }

    # fetchrow_hashref() returns undef on error or end-of-rows ... so have to distinguish!
    if ($DBI::err) {
        $logger->error("selectTable: $DBI::errstr");
        return false;
    }
    return true;
}

# [instance method] $bool = updateTable($sql, [\@bind_values])
# handle sql statement other than select
sub updateTable {
    my ($self, $sql, $bindArray_ref) = @_;
    my $logger = $self->{logger};
    $logger->debug("updateTable: '$sql'");
    if ($bindArray_ref) { $logger->debug(Dumper($bindArray_ref)); }
    if (!$self->{dbh}) {
        $logger->error("updateTable: database not open"); # assert
        return false;
    }
    my $rv = defined($bindArray_ref) ?
        $self->{dbh}->do($sql, undef, @{$bindArray_ref}) : $self->{dbh}->do($sql);
        # $rows = $dbh->do($statement, [\%attr, @bind_values])
        # do() returns undef on error otherwise # of rows or -1 if unknown
    if(!defined($rv)) {
        $logger->error("updateTable: rv = $rv, err = $DBI::err, errstr = $DBI::errstr");
        return false;
    }
    return true;
}

# [instance method] $bool = closeStore()
sub closeStore {
    my $self = shift;
    $self->{dbh}->disconnect();
    return true;
}

# @keys = getKeys($table)
# return list of primary keys in sequence order
sub getKeys {
    my $self = shift;
    my $table = shift;

    # tested but don't use
    # my @pkeys = ();
    # my $sth = $self->{dbh}->primary_key_info(undef, "main", $table);
    # while(my @row = $sth->fetchrow_array()) {
    #     push(@pkeys, $row[3]); # COLUMN_NAME
    # }

    # instead use the shorthand method
    my @pkeys = $self->{dbh}->primary_key(undef, "main", $table);

    $self->{logger}->trace("getKeys: @pkeys\n");
    return \@pkeys; # return reference
}

# @cols = getColumns($table)
# return list of all columns including primary keys
sub getColumns {
    my $self = shift;
    my $table = shift;

    my $sth = $self->{dbh}->column_info(undef, "main", $table, undef);
    my @cols = ();
    while(my @row = $sth->fetchrow_array()) {
        push(@cols, $row[3]); # COLUMN_NAME
    }

    $self->{logger}->trace("getColumns: @cols\n");
    return \@cols; # return reference
}

true; # need to end with a true value
