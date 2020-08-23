#!/usr/bin/perl

# Sample CGI frontend to Embedder

use strict;
use warnings;

use lib "$ENV{PREPRODIR}";
use Context;
use Embedder;

sub run {
    # when run under apache STDERR goes to apache error.log
    print STDERR "[frontend.cgi] started\n";

    # build context
    my $context = new Context;

    # run embedder
    Embedder::handle($context);
}

run();
