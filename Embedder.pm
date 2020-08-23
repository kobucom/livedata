#!/usr/bin/perl

# Embedder.pm - live data embedder (was data.pl)
# 2020-may-11 started; design started in may-09
# 2020-may-13 single row handling
# 2020-may-14 table row template handling
# 2020-may-15 ${?var}
# 2020-may-17 ${!view}
# 2020-may-21 no more data.cgi (shell) -> run as a perl cgi - ok
# 2020-may 25 data.pl -> Embedder.pm + Context.pm + Row.pm
# 2020-may-26 restructuring
# 2020-may-27 Logger.pm
# 2020-may-27 tested
#  run-data-cgi at local - OK
#  run-data-cgi on raspi - OK
#  data-fe.cgi (cgi-bin) - OK
#  data-fe.pl (mod_perl script) - looks working, no outpupt
#  data-fe.fcgi (fast-cgi) - looks working, no output
# 2020-may-29 web api (not tested yet)
# 2020-may-30 split handle() to handle() calling embed()
# 2020-may-31 multi-primary-key support
# 2020-jun-01 input type= support
# 2020-jun-04 action handling fixed - tested
#
# Modules:
#  frontend -> Context -> Embedder -> Table -> Store
#   CGI                       |                 sqlite3
#   FCGI                      v                 text file
#   mod_perl                Logger               ...
#   etc.
#
# Embedder::handle is an entry point. Embedder does not use any global variables.
# A frontend (such as CGI script) builds Context and calls handle().
# Any or new frontend can be built and calls Embedder in the same way.

package Embedder;

use strict;
use warnings;

use URI;
use Data::Dumper qw(Dumper);

use lib "$ENV{PREPRODIR}";
use Logger;
use Context;
use SqlTable;
use DbiStore;
use Row;

# constants
use constant { true => 1, false => 0, ALLOW_PK_CHANGE => 0 };

### macro functions

# macro formats:
# ${variable} - display macro
# ${?variable[/type[/list]]} - entry macro
# ${!action} - form action (add/update/delete) or view/edit link

# handleEntry($context, $var, $val, [$type, $list]) <- {$?variable[/type[/list]}
# data entry for variable
sub handleEntry {
    my ($context, $var, $val, $type, $list) = @_;

    # inhibit pk change
    my $disabled = !ALLOW_PK_CHANGE && $context->{_next_keys} &&
        ( grep { /^$var$/ } @{$context->{_table_handle}->{pkeys}} ) ? "disabled" : ''; 

    # default input type is 'text'
    if (!$type) { $type = 'text'; }

    if (grep { /^$type$/ } qw(text password email)) {
        return "<input type=\"$type\" name=\"$var\" value=\"$val\" $disabled />";
    }
    elsif (grep { /^$type$/ } qw(date time number range)) {
        return "<input type=\"$type\" name=\"$var\" value=\"$val\" $disabled />";
        # basically handled the same way as text but
        # can have 'min' and 'max' attributes
    }
    elsif (grep { /^$type$/ } qw(checkbox)) {
        # false if $val is empty otherwise true 
        my $checked = $val ? 'checked' : '';
        return "<input type=\"$type\" name=\"$var\" value=\"true\" $checked $disabled />";
    }
    elsif (grep { /^$type$/ } qw(radio select)) {
        my @array = split(/[,\s]\s*/, $list); # space or comma
        $context->{_logger}->trace("handleEntry: @array");
        my $output = '';
        if ($type eq "radio") {
            foreach my $e (@array) {
                my $checked = $e eq $val ? "checked" : '';
                $output .= "<input type=\"$type\" name=\"$var\" value=\"$e\" $checked $disabled />";
                $output .= ucfirst $e; # TODO: better way
            }
        }
        else { # select
            $output .= "<select name=\"$var\" $disabled>";
            $output .= "<option value=\"\">Select</option>";
            foreach my $e (@array) {
                my $selected = $e eq $val ? "selected" : '';
                $output .= "<option value=\"$e\" $selected >" . ucfirst $e . "</option>";
            }
            $output .= "</select>";
        }
        return $output;
    }
    else {
        return "\${$var}";
    }
}

# handleAction(context, action, query) <- ${!action}
#  action = edit/reset link buttons or add/update/delete form buttons 
#  query = hash reference to primary key-value pairs
sub handleAction {
    my ($context, $action, $query) = @_;
    $action = lc $action; # make lower

    my $enabled;
    if ($action eq 'reset') { # initial get_wo_query
        $enabled = true;
    }
    elsif ($context->{position} eq 'table') {
        $enabled = $action eq "edit"; # row exists
    }
    elsif ( $context->{position} eq 'form' ) {
        $enabled =
            ( $query && ($action eq "update" || $action eq "delete") ) ||
            ( !$query && $action eq "add" );
    }
    else { # elsewhere
        $enabled = $query && $action eq "edit";
    }

    if ($enabled && ( $action eq "add" || $action eq "update" || $action eq "delete") ) {
        # form button
        return "<button type=\"submit\" name=\"__action\" value=\"$action\">" .
            ucfirst($action) . "</button>"; # note name is "__action"
    }
    elsif ($enabled && ( $action eq "edit" || $action eq "reset") ) {
        # link button
        my $uri = new URI("/$context->{account}/$context->{table}.mdm");
        if ($query && $action ne "reset") { $uri->query_form($query); }
        my $actionPath = $uri->as_string();
        my $exec = "window.location.href = '$actionPath'";
        return "<button type=\"button\" onclick=\"$exec\" value=\"$action\">" .
            ucfirst($action) . "</button>";
            # value= is meaningless; just for debugging purpose
    }
    else {
        # disabled or unkown action
        return "<button type=\"button\" disabled>" . ucfirst($action) . "</button>";
    }
}

# [local utility funcion]
# hash_ref = limitHash($context, all_hash_ref, some_array_ref)
# remove key-value pairs in all_hash_ref whose keys are not present in some_array_ref.
# in other words, limit returned hash to that of some_array_ref.
sub limitHash {
    my ($context, $hash_ref, $array_ref) = @_;
    my %limited = map { $_ => $hash_ref->{$_} } @{$array_ref};
    my $limited_ref = \%limited;
    $context->{_logger}->trace("limitHash: " . Dumper $limited_ref);
    return $limited_ref;
}

# handleLine($context, $line, $row)
# called for a line that contains one or more macros
# also called from handleTableRow() to handle each generated table row
# note: row data available if 1) called from handleTableRow or
# 2) query string or post data is available when called directly from embed()
sub handleLine {
    my ($context, $line, $row) = @_;
    # note: $line contains trailing newline

    my $out = $context->{_out};
    my $logger = $context->{_logger};
    my $tableHandle = $context->{_table_handle};

    # note about pattern extraction:
    # ${^MATCH} etc. are available only if modifier 'p' specified while
    # $& / $` / $' are always available but generated even when unnecessary
    
    $logger->inline("LINE: '$line'");

    while (true) {
        if ($line =~ /\$\{[?!#]?[^}]+\}/p) {
            # $logger->trace("handleLine: '${^PREMATCH}' << '${^MATCH}' >> '${^POSTMATCH}'");

            # preserve matched portions (to avoid accidental destruction in further re use)
            my $prematch = ${^PREMATCH};
            my $macro = ${^MATCH};
            my $postmatch = ${^POSTMATCH};

            # Note: \w = [a-zA-Z0-9_] (includes underbar) and exactly matches
            # macro name restriction

            # output fragment prior to macro
            print $out $prematch;

            # handle macro
            $logger->trace("HandleLine: $macro");
            if ($macro =~ '\$\{\?(\w+)/?([a-z]*)/?([^}]*)\}') { # ${?var[/type[/list]]} - entry variable
                my $var = $1;
                my $type = $2;
                my $list = $3;
                my $val = '';
                if ($row) { $val = $row->{$var}; }
                $logger->inline("ENTRY: $var = $val, type=$type, list=$list");
                if ($context->{position} eq 'form') {
                    print $out handleEntry($context, $var, $val, $type, $list);
                }
                else {
                    print $out "\${?$var}";
                }
            }
            elsif ($macro =~ /\$\{!(\w+)\}/) { # ${!action} - action macro
                my $action = $1;
                # pass primary keys if there is a current row.
                my $query = undef;
                if ($row) {
                    # my %keyOnly = map { $_ => $row{$_} } $tableHandle->{pkeys};
                    $query = limitHash($context, $row, $tableHandle->{pkeys});
                }
                $logger->inline("ACTION: $action, query=" . Dumper $query);
                print $out handleAction($context, $action, $query);
            }
            elsif ($macro =~ /\$\{(\w+)\}/) { # ${var} - display variable
                my $var = $1;
                my $val = '';
                if ($row) { $val = $row->{$var}; }
                $logger->inline("MACRO: \${$var} = $val");
                print $out $val; # handled by HandleLine
            }
            else { # bad format
                print $out $macro;
            }

            # output fragment following macro
            $line = $postmatch;
        }
        else {
            print $out $line; # rest of the line
            last;
        }
    }
}

# handleTableRow($context, $line)
# called when $line is a table row with at least one macro
# this single line template is used to show listing of every row in the table
sub handleTableRow {
    my ($context, $line) = @_;

    my $out = $context->{_out};
    my $tableHandle = $context->{_table_handle};
    my $logger = $context->{_logger};

    $logger->inline("TABLE-ROW: $line");

    $context->{position} = 'table';
    $tableHandle->getRows(sub {
        my $hash_ref = shift;
        my $row = new Row($hash_ref);
        $logger->trace("handleTableRow-cb: " . Dumper $row);
        handleLine($context, $line, $row);
    });
    $context->{position} = '';
}

### web constructs

# execPostData($context)
#  $context->{action}
#    add|update|delete
#  $context->{post}
#   - primary keys and data for add
#   - data for update
#   - keys for delete
#  $context->{query}
#   - primary key-value pairs for update
sub execPostData {
    my $context = shift;
    my $postAction = $context->{action};
    my $tableHandle = $context->{_table_handle};
    my $logger = $context->{_logger};

    $logger->trace("execPostData: action=$postAction");

    if ($postAction eq "add") {
        my $cols_ref = limitHash($context, $context->{post}, $tableHandle->{cols});
        $tableHandle->addRow($cols_ref);
    }
    elsif ($postAction eq "update") {
        my $pkeys_ref = limitHash($context, $context->{query}, $tableHandle->{pkeys});
        my $cols_ref = limitHash($context, $context->{post},
            ALLOW_PK_CHANGE ? $tableHandle->{cols} : $tableHandle->{nkeys});
        $tableHandle->updateRow($pkeys_ref, $cols_ref);
    }
    elsif ($postAction eq "delete") {
        my $pkeys_ref = limitHash($context, 
            ALLOW_PK_CHANGE ? $context->{post} : $context->{query},
            $tableHandle->{pkeys});
        $tableHandle->deleteRow($pkeys_ref);
    }
    else {
        $logger->warn("$0: no such action: $postAction");
    }
}

# $nextKeys = determineNextKeys($context)
# determine keys to use for the next page
sub determineNextKeys {
    my $context = shift;
    my $tableHandle = $context->{_table_handle};
    my $nextKeys;
    if ($context->{method} eq "GET") {
        if ($context->{query}) {
            $nextKeys = limitHash($context, $context->{query}, $tableHandle->{pkeys});
        }
    }
    else { # POST
        if ($context->{action} ne "delete") {
            if ($context->{post}) {
                $nextKeys = limitHash($context, $context->{post}, $tableHandle->{pkeys});
            }
        }
    }
    return $nextKeys;
}

# embed($context)
# $context - request info set by frontend and working environment set by handle()
# parse input and write output
sub embed {
    my $context = shift;
    my $logger = $context->{_logger};
    my $mdfile = $context->{_in};
    my $pandoc = $context->{_out};

    # start banner
    $logger->log("[Embedder.pm] built 2020-Jun-04");
    $logger->log("Context: " . Dumper $context);

    # open table
    my $tableHandle = $context->{_table_handle} = new SqlTable($context->{table}, $context->{_store});

    # first thing to do: execute POST
    if ($context->{method} eq "POST") {
        execPostData($context); # write occurs to table
    }

    # determine primary keys for next op
    my $nextKeys = $context->{_next_keys} = determineNextKeys($context);

    # if pkeys are known, read the row data
    if ($nextKeys) {
        $tableHandle->getRow($nextKeys, sub {
            my $hash_ref = shift;
            $context->{row} = new Row($hash_ref);
            $logger->trace("getRow-cb: " . Dumper $context->{row});
        });
    }

    # Note: $context->{row} is local to embed(), so I can use just $row.
    # But I rather not use a closure variable in getRow() to avoid a possible trouble with mod_perl.

    # call sequence
    #  embed --+--> (1) HandleLine (inside or outside form)
    #          |
    #          +--> (2) HandleTableRow (within table) --> HandleLine
    # In (1) case the row data passed is either from post data, query string or none.
    # In (2) case the each row data comes a table.

    # http headers
    print STDOUT "Content-Type: text/html\n\n";

    my $lineCount = 0;
    $context->{position} = '';

    while ( my $line = <$mdfile> ) {
        $lineCount++;
        if ($line =~ /^\$form\$$/) { # $form$
            $context->{position} = 'form';
            my $uri = new URI("/$context->{account}/$context->{table}.mdm");
            if ($nextKeys) { $uri->query_form($nextKeys); } # set previous keys (which may change)
            my $actionPath = $uri->as_string();
            # 'method' is always 'post'; 'get' never used
            print $pandoc "<div class=\"box\">\n";
            print $pandoc "<form action=\"$actionPath\" method=\"post\">\n";
            # Note: the following is not right because duplicate but different
            # primary key values can be sent on update. I chose to add query string
            # even on post (update).
            # if ($nextKeys) {
            #     my %hash = %{$nextKeys};
            #     foreach my $k (keys %hash) {
            #         print $pandoc "<input type=\"hidden\" name=\"$k\" value=\"$hash{$k}\" />\n";
            #     }
            # }
        }
        elsif ($line =~ /^\$end\$$/) { # $end$
            print $pandoc "</form>\n";
            print $pandoc "</div><!-- box -->\n";
            $context->{position} = '';
        }
        elsif ($line =~ /\$\{[?!#]?[^}]+\}/) { # has macro
            # note no 'p' since no ${^MATCH}" used
            if ($line =~ /^\s*\$\|(.+)\|\$\s*$/) { # table row template
                # '$| ... | ... |$' => '| ... | ... |'
                handleTableRow($context, "|" . $1 . "|\n");
            }
            else {
                handleLine($context, $line, $context->{row}); # independent line or just table row
            }
        }
        else {
            print $pandoc $line;
        }
    }
}

# handle($context)
# handle a web request; setup working environment and call embed()
sub handle {
    my $context = shift;

    # setup logger
    my $debugLevel = $ENV{DEBUG_LEVEL} // 0;
    my $logger = $context->{_logger} = new Logger($debugLevel);

    # open data store (per-account database holding set of tables)
    my $store = $context->{_store} = new DbiStore("$context->{dir}/$context->{account}.db");
    $store->openStore();

    # file handles
    # STDIN  <- web request (post data)
    # STDOUT -> web response
    # STDERR -> apache error.log
    # MDFILE <- markdown source template, or
    # PANDOC -> piped output to pandoc which generates HTML and writes to STDOUT, or
    # if DEBUG_LEVEL is 2, MDFILE is set to STDIN and PANDOC is STDOUT

    # open md source in data directory (or stdin)
    my $mdfile = *STDIN;
    if ($debugLevel < 2) {
        my $filename = "$context->{dir}/$context->{table}.md";
        $logger->trace("markdown source: $filename");
        open(MDFILE, "< :encoding(UTF-8)", $filename) or die "$0: $filename: $!";
        $mdfile = *MDFILE;
    }
    $context->{_in} = $mdfile;

        # TODO: double fetch
        # check /acc/data then try /acc/admin/data

    # open pipe to pandoc (or stdout)
    my $pandoc = *STDOUT;
    if ($debugLevel < 2) {
        my $commandLine = "| pandoc -f gfm -t html5" .
            " -c \"pandoc-gfm.css\"" . # --css=URL
            " -T \"Live\"" . # --title-prefix=STRING
            " -M title=$context->{table}"; # --metadata=KEY[:VAL]
        $logger->trace("pandoc command: $commandLine");
        open(PANDOC, $commandLine) || die "$0: pandoc: $!\n";
        $pandoc = *PANDOC;
    }
    $context->{_out} = $pandoc;

    embed($context);

    # close data store
    $store->closeStore();
}

1; # need to end with a true value
