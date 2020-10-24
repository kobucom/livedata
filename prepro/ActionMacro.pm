package ActionMacro;

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use lib "$ENV{PREPRO_DATA}";
use Logger;
use Util;

# macro module
use DisplayMacro;

# constants
use constant { true => 1, false => 0 };

# $html = parseActionMacro($action, $title, $url, $context, $row)
#    <- $(!action[:title][>redir])
#  action = edit/reset link buttons or add/update/delete form buttons 
#  title = optional display name
#  url = optional redirect url for the action (inner macros are expanded)
#  row = current row (if exists)
sub parseActionMacro {
    my ($action, $title, $url, $context, $row) = @_;
    $action = lc $action; # make lower
    $title = Util::title($action, $title); # $(!action[:title])

    # 'view' is a synonym for 'edit'; meant to be used when no action buttons are offered
    if ($action eq "view") { $action = "edit"; }

    # determine button state based on position in a page
    my $enabled;
    if ($action eq 'reset' || $action eq 'submit') { # always available
        $enabled = true;
    }
    elsif ($context->{position} eq 'table') {
        $enabled = $action eq "edit"; # row exists
    }
    elsif ( $context->{position} eq 'form' ) {
        my $fillForm = $context->{keys} ? true : false;
        $enabled =
            ( $fillForm && ($action eq "update" || $action eq "delete") ) ||
            ( !$fillForm && $action eq "add" );
        # TODO: what about edit ?
    }
    else { # elsewhere
        $enabled = $row && $action eq "edit";
    }

    # generate button html
    if ($enabled && ($action eq "add" || $action eq "update" || $action eq "delete") ) {
        # form button
        my $html = qq(<button type="submit" name="__action" value="$action">) . $title . "</button>";
        # optional redirect for add/update/delete - $(!action[>url])
        if ($url) {
            my $name = "__redir_$action";
            my $redir = DisplayMacro::handleInnerMacros($url, $context, $row); # [macro] processed
            $html .= qq(<input type="hidden" name="$name" value="$redir" />\n);
        }
        return $html;
    }
    elsif ($enabled && ( $action eq "edit" || $action eq "reset") ) {
        # link button
        my $url = $context->{path}; # was buildFormUrl()
        my $uri = new URI($url);
        if ($action eq "edit" && $row) {
            # my %keyOnly = map { $_ => $row{$_} } $tableHandle->{pkeys};
            my $query = Util::limitHash($row, $context->{_th}->{pkeys});
            $query->{__action} = $action;
            $uri->query_form($query); # add primary keys/values + __action=edit
        }
        my $actionPath = $uri->as_string();
        my $exec = "window.location.href = '$actionPath'";
        return qq(<button type="button" onclick="$exec" value="$action">) . $title . "</button>";
            # value= is meaningless; just for debugging purpose
    }
    elsif ($action eq "submit") { 
        # convenience: 'submit' button for $form:link$ (non-table operation)
        return qq(<button type="submit">) . $title . "</button>";
    }
    else {
        # disabled or unkown action
        return qq(<button type="button" disabled>) . $title . "</button>";
    }
}

true; # need to end with a true value
