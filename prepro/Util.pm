#!/usr/bin/perl

package Util;

use strict;
use warnings;

use URI;

# use lib "$ENV{PREPRO_DATA}";
# use Logger;

# debug
# use Data::Dumper qw(Dumper);

# constants
use constant { true => 1, false => 0 };

# query_form_add($URI_instance, $hash_ref)
# add $hash_ref to $uri's query string
# not replace existing query string unlike URI::query_form() does
sub query_form_add {
    my ($uri, $hash_ref) = @_;
    my %hash = $uri->query_form();
    my %hash2 = (%hash, %{$hash_ref});
    $uri->query_form(\%hash2);
}

# $bool = has($value)
# it is not sufficient to say 'if ($value) ... ' for case of '0'
sub has {
    my $value = shift;
    return defined($value) && length($value) > 0;
}

# $title = title($name, [$title])
#  $name = id of somethig (\w+)
#  $title = title of that (any text)
sub title {
    my ($name, $title) = @_;
    if ($title) { return $title; }
    $name =~ tr/_/ /; # underbar -> space
    return ucfirst $name; # first captital
}

# ($domain, $pathInfo) = parseReferer($referer) <- http(s)://$domain$pattern
#  returns array of $domain and $pathInfo, or undef if pattern match failed
#  * $pattern includes '/'
sub parseReferer {
    my $referer = shift;
    my $domain;
    my $pathInfo;

    if (!$referer) { return undef; }

    if ($referer =~ '^https?://([^/]+)(/.*)$') {
        $domain = $1;
        $pathInfo = $2;
        return ($domain, $pathInfo);
    }

    return undef;
}

# @uniq_array = uniq(@array)
# remove duplicate elements
# https://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
sub uniq {
    my %seen;
    grep !$seen{$_}++, @_;
}

# $langs_ref = parseAcceptLanguage($acceptLanguage)
# parse HTTP_ACCEPT_LANGUAGE and return unique list of language codes as an array ref
# if missing, undef is returned
# HTTP_ACCEPT_LANGUAGE='en-us,en-uk;q=0.5,ja' -> [ en, en, ja ] -> [ en, ja ]
# see getlang.sh in prepro-author for a logic used here
sub parseAcceptLanguage {
    my $acceptLanguage = shift;
    if (!$acceptLanguage) { return undef; }
    # split ',' then take word before '-' or ';'
    my @list = split(/,\s*/, $acceptLanguage);
    my @codes = map { s/^(\w+)[-;]?.*$/$1/; $_; } @list;
    my @langs = uniq(@codes);
    return \@langs;
}

# PP_TODO: use Parser::flatten()
# $str = removeCRLF($lines) - 
# convert newlines to a space
# used to show multi-line textarea content in a table row
# originally written to change newlines to commas in parsePostData() for value_list
sub removeCRLF {
    my $lines = shift;
    # url-encoded version
    # $lines =~ s/%0[dD]%0[aA]/ /g;
    # $lines =~ s/%0[dD]/ /g;
    # $lines =~ s/%0[aA]/ /g;
    # raw text version
    $lines =~ s/\r\n/ /g;
    $lines =~ s/\r/ /g;
    $lines =~ s/\n/ /g;
    return $lines;
}

# hash_ref = parsePostData(escaped_query_string)
# return hash of key-value pairs from post data or query string in 
# 'application/x-www-form-urlencoded' format
#  postData: &-concatenated, %-encoded string
#  hash_ref: key-value pairs
# 20-08-03 rewritten with URI::query_form()
sub parsePostData {
    my $postData = shift;
    if (!$postData) { return undef; }
    # make URI module parse escaped parameters
    my $uri = new URI("/dummy?" . $postData);
    my %hash = $uri->query_form();
    return \%hash;
}

# $r = addZero($s, [$len])
# add leading zero to string of length $len
# '1' -> '01', '12' -> '12'
# up to $len <= 4
sub addZero {
    my ($s, $len) = @_;
    if (!$len) { $len = 2; }
    return substr('0000' . $s, -$len, $len);
}

# [was in Logger.pm]
# "yy/mm/dd-hh:mm:ss" = dateTime($epoch)
sub dateTime {
    my $epoch = shift;
    if (!$epoch) { $epoch = time; }
    my ($sec,$min,$hour,$day,$month,$year) = (localtime($epoch))[0,1,2,3,4,5];
    $month++;
    $year -= 100;
    # format: yyyy/mm/dd-hh:mm:ss
    return addZero($year) . '/' . addZero($month) . '/' . addZero($day) . '-' .
        addZero($hour) . ':' . addZero($min) . ':' . addZero($sec);
}

# [was in Embedder.pm]
# limited_hash_ref = limitHash(hash_ref, array_ref)
# limitHash finds an intersection of keys of hash_ref and array_ref
# returns a hash with key-value pairs of the intersection.
# limitHash({ a => 1, b => 2, c => 3 }, [ b, c, d ]) -> { b => 2, c => 3 } 
# limitHash({ a => 1, b = '', c => undef }, [ a, b, c, d ]) -> { a => 1, b = '' } 
# * value of '' is kept but undef is not
sub limitHash {
    my ($hash_ref, $array_ref) = @_;
    my %hash;
    foreach my $k (@{$array_ref}) {
        # There are three cases for marginal values:
        # 1) hash does not have a key
        # 2) hash has a key but the value is undef
        # 3) value is ''
        # key-value copied on 3) case only
        if (defined($hash_ref->{$k})) { $hash{$k} = $hash_ref->{$k}; } 
    }
    return %hash ? \%hash : undef; # return hash with some data
}

# [from Table.pm but not used even in Table.pm]
# \@rest = removeElements(\@all, \@some)
# remove elements in 'some' from 'all'
sub removeElements {
    my ($all_ref, $some_ref) = @_; 
    my @all = @{$all_ref};
    my @some = @{$some_ref};
    my %hash;
    @hash{@all} = ();
    delete @hash{@some};
    my @rest = keys %hash;
    return \@rest;
}

# [was in Table.pm]
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

true; # need to end with a true value
