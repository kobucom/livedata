package Context;

# Context.pm - build working environment for Embedder under CGI
# A frontend calls Embedder.pm to let it handle a web request.
# The frontend passes to Embedder.pm context information
# needed to handle the web request: per-request and system-wide variables.
#  - account
#  - table
#  - method (GET or POST)
#  - query
#  - action and post (if POST)
#  - root, dir
# these pieces of information are taken from:
#  - web request parameters (like CGI variables)
#  - system environment variables (that does not change over requests)
# Embedder.pm uses the conext instance to also hold temporary status variables
# shared between modules and subs. Underscore is prefixed to such variables.
#  - _logger
#  - _store
#  - _table_handle
#  - _in and _out
# In Embedder.pm, handle() builds such working environment and calls embed().
#
# 20-may-25 from data.pm::parseEnv()

use strict;
use warnings;

use URI;

use lib "$ENV{PREPRODIR}";
use Logger;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# constructor()
sub new {
    my $class = shift;
    my $logger = new Logger($ENV{DEBUG_LEVEL});
    my $self = { _logger => $logger };
    bless $self, $class;
    $self->parseEnv();
    return $self;
}

# [internal utility function] 
# $hash_ref = parsePostData($postData)
# build hash of key-value pairs from post data or query string in 
# 'application/x-www-form-urlencoded' format
#  postData: &-concatenated, %-encoded string
#  hash_ref: key-value pairs
sub parsePostData {
    my $postData = shift;
    if (!$postData) { return undef; }
    my $uri = new URI("/dummy?" . $postData);
    my %hash = $uri->query_form();
    return \%hash;
}

# [internal instance method]
# setPostData($hash_ref)
#  $context->{action} <= __action
#  $context->{post} <= hash data except __action
sub setPostData {
    my $self = shift;
    my $hash_ref = shift;
    $self->{action} = $hash_ref->{__action};
    delete $hash_ref->{__action};
    $self->{post} = $hash_ref;
}

# [internal instance method] parseEnv()
# extract parameters from environ variables and build context hash
sub parseEnv {
    my $self = shift;
    my $logger = $self->{_logger};

    # CGI variables passed through environ variables
    #   url: http://example.com/account/table.mdm[?query_string]
    #        HTTP_REFERER -> {referer}
    #          may be empty if url typed
    #          needed for checking for api
    #        REQUEST_METHOD -> {method}
    #          GET  list or view table rows
    #          POST table write operations
    #            post-data contains __action and key-value pairs
    #             -> {action} and {post}
    #        PATH_INFO=/account/table.mdm
    #          -> {account} and {table}
    #        QUERY_STRING=id=xxx -> key=val&key2=val2...
    #          -> {query}

    # HTTP_REFERER=url
    # $self->{referer} = $ENV{HTTP_REFERER};
    # $logger->debug("HTTP_REFERER=$self->{referer}");

    # REQUEST_METHOD=GET|POST
    $self->{method} = $ENV{REQUEST_METHOD};
    $logger->debug("REQUEST_METHOD=$self->{method}");

    # PATH_INFO = /account/table.mdm
    my $pathInfo = $ENV{PATH_INFO};
    $logger->debug("PATH_INFO=$pathInfo");
    if ($pathInfo) {
        # TODO: handle
        #  /acc/tbl.mdm
        #  /acc/tbl_entry.mdm
        #  /acc/tbl_list.mdm
        #  /acc/ticket/tbl.mdm
        #  /acc/tciket/...
        $pathInfo =~ s/\.mdm$//; # remove ".mdm" extension
        my @paths = split(/\//, $pathInfo);
        $self->{account} = $paths[1];
        $self->{table} = $paths[2];
    }

    # QUERY_STRING = key=val&key2=val2
    my $queryString = $ENV{QUERY_STRING};
    $logger->debug("QUERY_STRING=$queryString");
    if ($queryString) {
        $self->{query} = parsePostData($queryString);
    }

    # if POSTed from FORM, a table write operation is specified in post-data
    if ($self->{method} eq "POST") {
        my $postData = <STDIN>;
        chomp $postData;
        $logger->debug("POST=$postData");
        my $hash_ref = parsePostData($postData);
        $self->setPostData($hash_ref);
    }

    # environment-specific parameters set in conf and passed by apache
    #   $PREPRODIR
    #     directory holding embedder perl scripts
    #   $DATAROOT
    #     directory where URL '/' points to (/var/www/dav)
    #     parent directory of accounts' directory
    #     used to determine:
    #       $DATADIR="$DATAROOT/$ACCOUNT/data"
    #         hidden data directory where md source and table files reside

    # DATAROOT = /var/www/dav
    $self->{root} = $ENV{DATAROOT};

    if (!$self->{root} || !$self->{account} || !$self->{table}) {
        die "[ERROR] $0: path info missing";
    }

    # now DATADIR is known
    $self->{dir} = "$self->{root}/$self->{account}/data";
}

1; # need to end with a true value

