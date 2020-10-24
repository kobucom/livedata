package Link;

# Link.pm - experimental link and webapi syntax: $[label](url)
# 20-jul-04 from Embedder.pm
# 20-jul-26 use of ! reversed -> api if ! attached
# 20-sep-07 % api check done in Embedder.pm side

# TODO: web-api value macro
# who gets value?
#  - server calls api and embed response value
#  - let the browser call api - generate <span id="xxx"/>, add call api on load
# how about syntax?
#  - $[%](webapi)
#  - ${%webapi}
#   response data is placed at this position
#   same as markdown standard [label](url) but extended label syntax can be used  
# * if a link or webapi have ${macro} in it, it should not be nested in ${...}
#   it should be outside ${...} or within embedder-special link-derived syntax:

use strict;
use warnings;

use lib "$ENV{PREPRO_DATA}";
use Logger;

# debug
use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# normal link syntax: page reload hyperlink
#  any url that can appear in markdown link syntax: [label](url)
#   [[http(s)://]domain]/path_info[?query_string] 
#    * the slash in front of path_info belongs to path_info
#    * query_string is assumed to be part of a link url
#  examples:
#   /guest/schema.mdm
#   /guest/schema.mdm?table=${table}
#   example.com/guest/schema.mdm
#   example.com/guest/schema.mdm?table=${table}
#   http://example.com/guest/schema.mdm
#   http://example.com/guest/schema.mdm?table=${table}
#
# extended url can only appear in extended link syntax: $[[%]label](eurl)
#   [method>]url[<postdata]
#     - 'method' can be case-insensitive and GET if missing
#     - query string of ?... in link and post data of <... can coexists (at least in syntax)
#     - webapi syntax should be enclosed in $[...](url) wrapper which further includes
#       ${...} macros
#     * HandleLine process ${...} then $[...](...)
#  Note: POST is only supported for api; only GET implemented for page-reload link
#  examples:
#   /guest/schema.mdm (link can be a webapi) - GET
#   post>/guest/schema.mdm?table=${table}
#   post>/guest/schema.mdm<account=${account}
#   post>/guest/schema.mdm?table=${table}<account=${account}
#
#  two forms of extended link:
#  - $[label](eurl) - extended link syntax: page reload button
#  - $[%label](eurl) - webapi syntax: javascript ajax call button

# TESTED but NOT USED in dbhosting yet
# @array = parseApi($eurl)
#  $eurl = [method>]url[<postdata] (extended url)
#  @array = ($method, $url, [$postdata])
# $url part may contain query string (?x=y)
sub parseApi {
    my $eurl = shift;
    if ($eurl =~ /^((\w+)>|)([^><]+)(<(.+)|)$/) {
        my $method = 'GET';
        if ($2) { $method = uc $2; }
        my $url = $3;
        my $postdata = $5;
        return $postdata ? ($method, $url, $postdata) : ($method, $url);
    }
    return undef;
}

# embedder-special link-derived syntax: $[[%]label](eurl)
# value-added link button
#  $[label](eurl)
# web api call button
#  $[%label](eurl)
#   button for webapi is generated; response data is shown in a browser popup

# extended label syntax: label in $[[%]label](eurl) - NOT USED
#  [%]name[/stat]
#   name
#    - name
#    - predicate?name_on_true:name_on_false
#   stat
#    - predicate (if exists)
#  available predicates
#   next_keys - true if $context->{next_keys} exists
#   agreeable - true if next_keys and /var/www/dav/$account exists   

# boolean = execPredicate($predicate, $context)
sub execPredicate {
    my ($predicate, $context) = @_;
    if ($predicate eq "next_keys") {
        return $context->{next_keys} ? true : false;
    }
    elsif ($predicate eq "agreeable") {
        # next_keys && account_dir
        return $context->{next_keys} && -d "$context->{rootdir}/$context->{account}";
    }
    elsif ($predicate eq "true") { # for test
        return true;
    }
    elsif ($predicate eq "false") { # for test
        return false;
    }
    else {
        die "No such predicte: $predicate";
    }
}

# NOT TESTED after mods
# converted = handleLink(isApi, label, eurl, context)
# handle embedder-special link-derived syntax, $[[%]label](eurl)
#  webapi button if '%' attached otherwise normal hyperlink button
# macros in label and eurl parts are already expanded prior to call handleLink()
sub handleLink {
    my ($isApi, $label, $eurl, $context) = @_;
    my $logger = $context->{logger};

    my @array = parseApi($eurl);
    $context->{logger}->debug("handleLink: api = $isApi, " . Dumper(\@array));
    if (@array != 3 && @array != 2) {
        return "<button type=\"button\" disabled>" . $label . "</button>";
    }

    my $method = $array[0];
    my $url = $array[1];
    my $postData = @array == 3 ? $array[2] : '';
    my $disabled = '';

    # TODO: make readable; $pred1 is $name if no predicate

    # parse label
    if ($label =~ /^([^\?\/]+)(\?([^:]+):([^\/]+)|)(\/(.+)|)$/) {
        my $pred1 = $1;
        my $name1 = $3;
        my $name2 = $4;
        my $pred2 = $6;

        # if ($pred1) { $logger->debug("pred1: $pred1"); }
        # if ($name1) { $logger->debug("name1: $name1"); }
        # if ($name2) { $logger->debug("name2: $name2"); }
        # if ($pred2) { $logger->debug("pred2: $pred2"); }

        if ($name2) { # then pred1 and name1 also exist
            $label = execPredicate($pred1, $context) ? $name1 : $name2; # pred1?name1:name2
        }
        else {
            $label = $pred1; # first one if no '?'
        }

        # if 'disabled' predicate specified, it must be true so that the button is available
        #  pred2 missing - enabled
        #  pred2 specified and true - enabled
        #  pred2 specified and false - disabled
        if ($pred2) {
            $disabled = execPredicate($pred2, $context) ? '' : " disabled";
        }
    }
    else {
        die "Invalid label: $label";
    }

    if ($isApi) {
        my $call = $postData ?
            "callApi('$label', '$method', '$url', '$postData')" :
            "callApi('$label', '$method', '$url')";
        return "<button type=\"button\" onclick=\"$call\"$disabled>" . $label . "</button>";
    }
    else { # link
        my $jump = "window.location.href = '$url'";
        return "<button type=\"button\" onclick=\"$jump\"$disabled>" . $label . "</button>";
    }
}

true; # need to end with a true value
