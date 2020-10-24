#!/usr/bin/env perl

# Sample CGI frontend to Embedder
# Written 2020-Jul-15
# Updated 2020-Oct-23

use strict;
use warnings;

use lib "$ENV{PREPRO_DATA}";
use Logger;
use Embedder;

sub run {
    # when run under apache STDERR goes to apache error.log
    print STDERR "[frontend.cgi] started\n";

    # build context in which embedder runs
    my $context = {};
    $context->{logger} = new Logger;
    #$context->{page_vars} = [ qw(method path table) ]; # see DisplayMacro::getPageVariable()

    # get request parameters
    $context->{path} = $ENV{PATH_INFO} // $ENV{REQUEST_URI}; # markdown source path
    $context->{method} = $ENV{REQUEST_METHOD};
    $context->{query} = Util::parsePostData($ENV{QUERY_STRING});
    if ($context->{method} eq "POST") {
        my $postData = <STDIN>;
        $context->{post} = Util::parsePostData($postData);
    }

    # get '__action' parameter which specifies type of table operation
    my $from = $context->{method} eq "POST" ? 'post' : 'query';
    my $action = $context->{$from}->{__action};
    if ($action) {
        $context->{control} = { action => $action };
        if ($action eq 'edit') { $context->{keys} = $context->{qeury}; } # used to fill form
    }

    # open data store which contains target table
    my $store = $context->{_store} = new DbiStore($ENV{DBPATH});
    $store->openStore();

    # open table
    my $tableName = $context->{path}; # '/customer.md'
    $tableName =~ s/\/(\w+)\.md$/$1/; # basename == tablename
    $context->{table} = $tableName;    
    $context->{_th} = new SqlTable($tableName, $store);
    
    # call embedder for table write operation
    if ($context->{method} eq "POST") {
        Embedder::execPost($context);
    }

    # setup input
    # my $input = \*STDIN; # apache filter - markdown source comes from stdin
    my $filename = "$ENV{DOCUMENT_ROOT}$context->{path}"; # apache handler
    open(my $input, "<", $filename)
        or die "Can't open markdown source: $filename";

    # setup output
    open(my $output, "|-", 'pandoc -f gfm-autolink_bare_uris -t html5')
        or die "Can't pipe to pandoc: $!";

    # call embedder
    Embedder::embed($input, $output, $context);

    # close pipe
    close $output;

    # close data store
    $store->closeStore();
}

run();
