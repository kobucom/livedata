package DisplayMacro;

# 2020-oct-16 split from Embedder.pm
# 2020-oct-23 {page_vars}

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use lib "$ENV{PREPRO_DATA}";
use Logger;
use Util;

use lib "$ENV{PREPRO_AUTHOR}";
use Parser qw(parseLine flatten); # PP_TODO:

# constants
use constant { true => 1, false => 0 };

# $value = getPlainVariable($var, $row)
# return $value for $var in $row; valid only if the current row exists
sub getPlainVariable {
    my ($var, $row) = @_;
    if (!$row) { return ''; }
    my $value = $row->{$var};
    if (!$value) { return ''; }
    my $removed = Util::removeCRLF($value); # for text in textarea - PP_TODO: flatten()
    #print STDERR "\nremoved = $removed\n\n";
    return $removed;
}

# $value = getPageVariable($var, $context, $row)
# var = page variable: $(.var) or [.var]
# row = current row
# source of page variable, in the order of precedence:
# 1) calculated value, eg. datetime
# 2) control parameter, eg. action, lang
#    query or post data of the form __action=xxxx is stored in
#    $context->{control}->{action}
# 3) state value in $context , eg. method
#    not all values are string and some must be hidden for security reason
#    you can provide {page_vars} array to limit available variables 
sub getPageVariable {
    my ($var, $context, $row) = @_;

    #1) calcuated value
    if ($var eq 'datetime') { return Util::dateTime(); }
    elsif ($var eq 'unixtime') { return time; }

    #2) control parameter
    my $value = $context->{control}->{$var};
    if (Util::has($value)) { return $value; }

    #3) context value (checked against {page_vars})
    $value = $context->{$var};
    if (Util::has($value)) {
        if (defined($context->{page_vars})) {
            my @pageVars = @{$context->{page_vars}};
            if (!grep(/^$var$/, @pageVars)) {
                return ''; # not on the allow list
            }
        }
        return $value;
    }

    # no such variable
    return '';
}

# Note: NOT IMPLEMENTED YET
# $value = getAltVariable($alt, $var, $context, $row) <- $(alt.var)
# handle special display variable: alternate talbe or page variable denoted by '_.var'
#   $alt - alternate table name or '_' for page variable
#   $var - variable name
#   $row - current row
sub getAltVariable {
    my ($alt, $var, $context, $row) = @_;
    $context->{logger}->warn("getAltVariable not implemented");
    my $value = '';
    if ($row) {
        # take id value of the current row of the main table
        my $mainKeyName = $context->{table};
        my $mainKeyVal = $row->{$mainKeyName};
        if (Util::has($mainKeyVal)) {
            $context->{logger}->trace("getAltVariable: select $var from $alt where $mainKeyName = $mainKeyVal");
            # TODO:
            #  1) $context->{rows_$alt} = getRows() where $mainKeyName = $mainKeyVal
            #  2) get value of $var
        }
    }
    return $value || '';
}

# $value = parseDisplayMacro($alt, $dot, $var, $context, $row) <-- $([[alt].]var)
# handle plain, alternate and page variables
sub parseDisplayMacro {
    my ($alt, $dot, $var, $context, $row) = @_;
    my $logger = $context->{logger};
    my $value = '';
    if ($alt) {
        $value = getAltVariable($alt, $var, $context, $row);
        $logger->trace("ALT: $alt.$var = $value");
    }
    elsif ($dot) {
        $value = getPageVariable($var, $context, $row);
        $logger->trace("PAGE: .$var = $value");
    }
    else {
        $value = getPlainVariable($var, $row);
        $logger->trace("DISP: $var = $value"); # TODO: undef warning
    }
    return $value;
}

# $converted = handleInnerMacros($str, $context, $row);
# handle inner display variables (plain, alt, page) enclosed in the form of [macro]
# called from:
# - parseHiddenParameter() <- $(+name=value)
# - handleFormBegin() <- $form:link$
# - handleLine() <- extended links: $[label](eurl)
# - parseActionMacro() <- $(!action>redir) 
# eg. $(+__select=[.select]), $form:/[.account]/schema.mdmp$
sub handleInnerMacros {
    my ($str, $context, $row) = @_;
    $context->{logger}->trace("handleInnerMacro: $str");
    return parseLine($str, [{
        # $([[alt].]var) - display macro (alternate, page and plain variables)
        # NOTE: exactly the same code in handleLine() duplicated here
        # TODO: if (($value = handleDisplayMacro($macro, $context, $row)) != undef)
        # which returns undef if pattern doesn't match or '' if pattern matched but
        # value is empty
        testpat => '\[',
        pattern => '\[(((\w+)|)(\.)|)(\w+)\]',
                    # 3:alt  4:dot 5:var
        code => sub {
            my ($span, $context, $row) = @_;
            my $alt = $3;
            my $dot = $4;
            my $var = $5;
            return parseDisplayMacro($alt, $dot, $var, $context, $row);
        }
    }], $context, $row);
}

true; # need to end with a true value
