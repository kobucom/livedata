#!/usr/bin/perl

# Embedder.pm - live data embedder (was data.pl)
#
# Copyright (c) 2020 Kobu.Com. Some Rights Reserved.
# Distributed under GNU General Public License 3.0.
# Contact Kobu.Com for other types of licenses.
#
# 2020-may-11 started; design started in may-09
#   see changes.txt for the rest of the mods history
#
# Embedder is the core of the live data embedder.
# A frontend (such as CGI script) builds an executing context and calls Embedder.
# A different frontend can be built to support a different environment.
# Embedder does not use any global variables in order to support resident
# environment such as mod_perl and fast cgi.
#
# Modules:
#  frontend -> Embedder -> Table -> Store
#   CGI(*)                          sqlite3(*)
#   FCGI                            text file
#   mod_perl                        etc.
#   etc.
#  * currently supported
#
# Entry points:
#  POST request -> execPost() then embed()
#  GET request -> embed()
#
# handleXXX() call sequences:
#  row template --> handleTableRows() --+                   
#                                       +--> handleLine() --> parseLine()
#  other lines -------------------------+
#
# Current row passed to handleLine():
#  [edit] in html table -> getRows() called with {Keys} to fill in form
#  [update] or [delete] in form -> data set by execPost() used except in form
#  [add] -> data set by execPost() used except form

package Embedder;

use strict;
use warnings;

use URI;
use Data::Dumper qw(Dumper);

use lib "$ENV{PREPRO_AUTHOR}";
use Parser qw(parseLine flatten);

use lib "$ENV{PREPRO_DATA}";
use Logger;
use Util;
use SqlTable;
use DbiStore;
use Link;

# macro modules
use DisplayMacro;
use EntryMacro;
use ActionMacro;

# constants
use constant { true => 1, false => 0 };

# stdxxx encoding
#use open qw/:std :utf8/;

    # said that this should be specified prior to any print

# default file encoding - so that you don't have to say each time:
#   open($input, "< :encoding(UTF-8)", $filename);
#use open qw< :encoding(UTF-8) >;

    # https://perldoc.perl.org/perlunitut.html
    # Using :utf8 for input can sometimes result in security breaches,
    # so please use :encoding(UTF-8) instead.

    # * see 'mktbl.cgi' for why these are commented out
    
# html-input-tag = parseHiddenParameter($name, $value, $isControl, $context, $row)
# output hidden input tag:
# - $(+name[=value]) -> name = value
# - $(++name[=value]) -> __name = value 
# $value may contain inner macros: "text" or "foo [bar] baz" etc.
sub parseHiddenParameter {
    my ($name, $value, $isControl, $context, $row) = @_;
    if (not $context->{position} eq 'form') { return undef; }
    my $converted = DisplayMacro::handleInnerMacros($value, $context, $row);
    my $prefix = $isControl ? '__' : '';
    return qq(<input type="hidden" name="$prefix$name" value="$converted" />\n);
}

# $output = handleLine($line, $context, $row)
# called from: 
# - embed() to process a source line, or from
# - handleTableRows() to handle each generated table row.
# the line may or may not contain one or more macros and/or extended links:
# - all embedder macros are in the form of $(...) and processed first,
# - extended links are in the form of $[...](...) and handled at the end
# row data exists if:
# - called from handleTableRows or
# - called from embed() and query string or post data is available
sub handleLine {
    my ($line, $context, $row) = @_; # $line contains trailing newline
    my $logger = $context->{logger};
    return parseLine($line, [
        {
            # hidden parameter (form only)
            # - $(+name[=value]) - table data
            # - $(++name[=value]) - control data (same as __name)
            # syntax design changes: 
            #  page variables in form: +var, =var -> hidden parameters: $(+name[=value])
            #  page variable anywhere: .var -> handled as part of display macro: $([[alt].]var)
            testpat => '\$\(\+',
            pattern => '\$\((\+\+?)(\w+)(\=(([^)]+)|)|)\)',
            #               1:+/++ 2:name   5:value
            code => sub {
                my ($span, $context, $row) = @_;
                # form only - the check is done at the called side for readability
                my $isControl = $1 eq "++";
                my $name = $2;
                my $valueWithMacros = $5;
                $logger->trace("HIDDEN: " . ($isControl ? '__' : '') . "$name = " . ($valueWithMacros // ''));
                my $value = parseHiddenParameter($name, $valueWithMacros, $isControl, $context, $row);
                return $value // ''; # unrecognized hidden parameter printed as ''
            }
        },
        {
            # entry variable - $(?[?]column_name[:column_title][/entry_type[:value_list]]
            #                     [#default_value][~pattern[:pattern_note]])
            # * syntax changed: required = $(&...) -> $(??...)
            testpat => '\$\(\?',
            pattern => '\$\((\?\??)(\w+)(:([^/#~]+)|)(/([^:#~]+)(:([^#~]+)|)|)(#([^~]+)|)(~([^:]+)(:(.+)|)|)\)',
            #              1:?/?? 2:var  4:title      6:type     8:list        10:defval  12:pat   14:p-note
            code => sub {
                my ($span, $context, $row) = @_;
                my $var = $2;

                my $fillForm = $context->{keys} ? true : false;
                my $value = $row && $fillForm ? $row->{$var} : '';

                my $options = {};
                $options->{required} = $1 eq '??'; # required if ?? otherwise ?
                $options->{column_title} = $4;
                $options->{entry_type} = $6;
                $options->{value_list} = $8;
                $options->{default_value} = $10;
                $options->{pattern} = $12;
                $options->{pattern_note} = $14;

                $logger->trace("ENTRY: $var = $value, " . Dumper($options));
                return EntryMacro::parseEntryMacro($var, $value, $context, $options);
            }
        },
        {
            # $(!action[:title][>url]) - action macro
            testpat => '\$\(!',
            pattern => '\$\(!(\w+)(:([^}>)]+)|)(>([^}]+)|)\)',
            #                1:act  3:title      5:url
            code => sub {
                my ($span, $context, $row) = @_;
                my $action = $1;
                my $title = $3;
                my $url = $5;
                $logger->trace("ACTION: $action, title = " . ($title // '') . ' redir = ' . ($url // ''));
                return ActionMacro::parseActionMacro($action, $title, $url, $context, $row);
            }
        },
        {
            # $([[alt].]var) - display macro (alternate, page and plain variables)
            testpat => '\$\([\w.]',
            pattern => '\$\((((\w+)|)(\.)|)(\w+)\)',
            #                3:alt  4:dot 5:var
            code => sub { # TODO: same code used in handleInnerMacro()
                my ($span, $context, $row) = @_;
                my $alt = $3;
                my $dot = $4;
                my $var = $5;
                return DisplayMacro::parseDisplayMacro($alt, $dot, $var, $context, $row);
            }
        },
        {
            # extended link-derived syntax: $[[%]label](url)
            testpat => '\$\[',
            pattern => '\$\[(%?)([^]]+)\]\(([^)]+)\)',
            #              1:% 2:label    3:eurl
            code => sub { # was expandLinks()
                my ($span, $context, $row) = @_;
                my $isApi = $1 ? true : false; # api if % otherwise just hyperlink
                my $label = $2; # TODO: has inner macros?
                my $eurl = $3;
                $eurl = DisplayMacro::handleInnerMacros($eurl, $context, $row);
                return Link::handleLink($isApi, $label, $eurl, $context);
            }
        }
    ], $context, $row);
}

# handleTableRows($output, $line, $context) <- $| ... |$
# called when $line is a table row template
# the single line template results in printing of every row in the table
sub handleTableRows {
    my ($output, $line, $context) = @_;
    my $tableHandle = $context->{_th};
    my $logger = $context->{logger};
    $logger->trace("TABLE-ROW: $line");
    $tableHandle->getRows(sub {
        my $hash_ref = shift;
        my $row = $hash_ref;
        $logger->trace("handleTableRows-cb: " . Dumper($row));
        print $output handleLine($line, $context, $row);
    }) or die "Can't read the table";
}

# handleFormBegin($output, $link, $context) <- $form[:link]$
sub handleFormBegin {
    my ($output, $link, $context) = @_;
    my $url = $link ?
        DisplayMacro::handleInnerMacros($link, $context, $context->{row}) : # was buildFormUrl()
        $context->{path};
    my $uri = new URI($url);
    if ($context->{keys}) { # set keys passed via edit button to query string 
        Util::query_form_add($uri, $context->{keys}); # add (not overwrite) keys
    }
    my $actionPath = $uri->as_string();
    # 'method' is always 'post'; 'get' never used
    print $output qq(<div class="box">\n);
    print $output qq(<form action="$actionPath" method="post">\n);
}

# handleFormEnd($output) <- $end$ of $form$
sub handleFormEnd {
    my $output = shift;
    print $output "</form>\n";
    print $output "</div><!-- box -->\n";
}

# embed($input, $output, $context)
# converts macro-embedded source ($input) to plain markdown ($output)
# called on GET or after execPost() on POST without redirect
# $context - information about request and environment set by the frontend
#   logger
#   _th     table handle
#   keys    primary keys passed by edit button; indicates a form should be filled
#   row     [GET]  if edit, embed() reads row based on {keys} and fills by itself
#           [POST] on add/update, execPost() sets cols in postdata, none on delete
# $context is also used to share internal variables within this module:
#   position - form, table or elsewhere ('')
sub embed {
    my ($input, $output, $context) = @_;
    my $logger = $context->{logger};
    my $tableHandle = $context->{_th};

    # if GET/edit button -> get {keys} and read {row} data used to fill a form
    if ($context->{method} eq "GET" && ## TODO error - string eq ???
        $context->{control} && $context->{control}->{action} eq "edit") {
        # TODO: check if {query} is valid
        my $passedKeys = $context->{keys} = Util::limitHash($context->{query}, $tableHandle->{pkeys});
        $logger->debug("passed keys on edit: " . Dumper($passedKeys));
        $tableHandle->getRow($passedKeys, sub {
            my $hash_ref = shift;
            $context->{row} = $hash_ref;
            $logger->trace("getRow-cb: " . Dumper($context->{row}));
        }) or die "Can't read the row";
        if (!$context->{row}) { die "Row not found"; }
    }

    $context->{position} = '';
    while ( my $line = <$input> ) {
        if ($line =~ /^\$form(:([^\$]+)|)\$\s*$/) { # $form[:link]$
            my $link = $2;
            $context->{position} = 'form';
            handleFormBegin($output, $link, $context);
            print $output "\n"; # let pandoc treat inline html with other text
        }
        elsif ($line =~ /^\$end\$\s*$/) { # $end$
            print $output "\n\n"; # extra newline
            handleFormEnd($output);
            $context->{position} = '';
        }
        elsif ($line =~ /^\s*\$\|(.+)\|\$\s*$/) { # $| ... |$ - table row template
            # '$| ... | ... |$' => '| ... | ... |'
            $context->{position} = 'table';
            handleTableRows($output, "|" . $1 . "|\n", $context); # calls handleLine() inside
            $context->{position} = '';
        }
        else {
            print $output handleLine($line, $context, $context->{row});
        }
    }
}

# execPost($context)
# handle POST operation; 1) write to table, 2) setup current row in {row}
# $context - information about request and environment set by the frontend
#   method  http method (GET or POST)
#   query   hash of query string (GET or POST)
#   post    hash of post data (POST only)
#   control->{action}  add/update/delete if POST, edit/reset/none if GET
# execPost will get (<) and set (>):
#  > $context->{control}->{action}
#    add|update|delete
#  > $context->{post}
#   - all columns (pkey- and non-key columns) for add
#   - all columns for update
#   - nothing for delete
#  > $context->{query}
#   - nothing for add
#   - pkeys for update
#   - pkeys for delete
#  < $context->{row}
#   - post data on add
#   - query and post data merged on update
#   - nothing set on delete
# TODO: if allow_pk_change, on delete, posted keys are editable, what to do?
# Note: in query/post data, xxx= is empty data ('') and missing data is undef
#       on update, undef is ignored while '' clears existing data
#       on add, undef and '' makes no difference, the column has no data
sub execPost {
    my $context = shift;
    my $logger = $context->{logger};
    my $tableHandle = $context->{_th};
    my $action = $context->{control}->{action};

    $logger->debug("execPost: action=$action");

    if ($action eq "add") {
        my $cols_ref = Util::limitHash($context->{post}, $tableHandle->{cols});
        $tableHandle->addRow($cols_ref)
            or die "Can't add the row ... probably because it already exists";
        $context->{row} = $cols_ref;
    }
    elsif ($action eq "update") {
        my $pkeys_ref = Util::limitHash($context->{query}, $tableHandle->{pkeys});
        my $cols_ref = Util::limitHash($context->{post}, $tableHandle->{cols});
        my $vals_ref = EntryMacro::ALLOW_PK_CHANGE ? $cols_ref :
            Util::limitHash($context->{post}, $tableHandle->{nkeys});
        $tableHandle->updateRow($pkeys_ref, $vals_ref) or die "Can't update the row";
            # TODO: not error even if no record
        my %merged = (%{$pkeys_ref}, %{$cols_ref});
        $context->{row} = \%merged;
        $logger->trace("execPost: update:\nkeys = " . Dumper($pkeys_ref) .
            "cols = " . Dumper($cols_ref) .
            "vals = " . Dumper($vals_ref) .
            "{row} = " . Dumper($context->{row}));
    }
    elsif ($action eq "delete") {
        my $pkeys_ref = Util::limitHash($context->{query}, $tableHandle->{pkeys});
        $tableHandle->deleteRow($pkeys_ref)
            or die "Can't delete the row";
    }
    else {
        die("No such action: $action");
    }
}

true; # need to end with a true value
