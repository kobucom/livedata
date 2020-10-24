package EntryMacro;

use strict;
use warnings;

use Data::Dumper qw(Dumper);

use lib "$ENV{PREPRO_DATA}";
use Logger;
use Util;

# constants
use constant { true => 1, false => 0 };
use constant { ALLOW_PK_CHANGE => false };

# [local utility - TODO: move to Util?]
# ($name, $title) = getNameAndTitle($name_colon_title)
#   $name_colon_title - name[:title]
#   returns
#     $name - id
#     $title - specified name or uppercased and underbar-spaced id
sub getNameAndTitle {
    my $nameTitle = shift;
    if (!$nameTitle) { return ('unknown', 'Unknown'); }
    my ($name, $title) = split(/:/, $nameTitle);
    $title = Util::title($name, $title);
    return ($name, $title);
}

# $html = parseEntryMacro($var, $value, $context, $options)
#   <-- $(?[?]column_name[:column_title][/entry_type[:value_list]]
#          [#default_value][~pattern[:pattern_note]])
#       where value_list = name[:title],...
# data entry for variable
#   $var == column_name
#   $value == current value
#   $options contains:
#     - required
#       * added except for checkbox
#     - entry_type
#     - value_list
#     - column_title - ignored
#       TODO: <label for="name">title</label><input ... id="name" name="name" ...>
#     - default_value
#     - pattern
#     - pattern_note
sub parseEntryMacro {
    my ($var, $value, $context, $options) = @_;
    my $title = $options->{column_title};
    my $type = $options->{entry_type};
    my $list = $options->{value_list};
    my $defval = $options->{default_value};
    my $pattern = $options->{pattern};
    my $patternNote = $options->{pattern_note};
    my $required = $options->{required} ? 'required' : '';

    # inhibit pk change
    my $disabled = !ALLOW_PK_CHANGE && Util::has($value) &&
        $context->{keys} && ( grep { /^$var$/ } @{$context->{_th}->{pkeys}} )
            ? 'disabled' : ''; 

    # default input type is 'text'
    if (!$type) { $type = 'text'; }

    # place default value if $value empty
    if (!Util::has($value) && Util::has($defval)) { $value = $defval; }

    # group #1 - selection list (should have value_list but fail-safe even if none)
    if (grep { /^$type$/ } qw(radio select)) {
        my @array = split(/\s*,\s*/, $list);
        $context->{logger}->trace("parseEntryMacro: @array");
        my $output = '';
        if ($type eq "radio") {
            for (my $i = 0; $i < @array; $i++) {
                my ($name, $title) = getNameAndTitle($array[$i]);
                my $checked = $name eq $value ? "checked" : '';
                $output .= qq(<input type="$type" name="$var" value="$name" $checked $disabled $required/>);
                $output .= $title;
            }
        }
        else { # select
            $output .= qq(<select name="$var" $disabled $required>);
            $output .= qq(<option value="">blank</option>);
            for (my $i = 0; $i < @array; $i++) {
                my ($name, $title) = getNameAndTitle($array[$i]);
                my $selected = $name eq $value ? "selected" : '';
                $output .= qq(<option value="$name" $selected>) . $title . "</option>";
            }
            $output .= "</select>";
        }
        return $output;
    }
    # group #2 - pattern-applicable (can have pattern)
    elsif (grep { /^$type$/ } qw(text password email tel)) { # 'tel' added
        my $output = qq(<input type="$type" name="$var" value="$value");
        if ($pattern) {
            $output .= ' pattern="' . $pattern . '"';
            if ($patternNote) {
                $output .= ' title="' . $patternNote . '"';
            }
        }
        $output .= " $disabled $required />";
        return $output;
    }
    # group #3 - has a range
    elsif (grep { /^$type$/ } qw(date time number)) { # no 'range'
        return qq(<input type="$type" name="$var" value="$value" $disabled $required />);
        # basically handled the same way as text but
        # can have 'min' and 'max' attributes but not supported
        # min/max is required for 'range' so this is not included
    }
    # others - no list, no pattern, no range
    else {
        if (grep { /^$type$/ } qw(textarea)) {
            #  rows="4" cols="50"
            return qq(<textarea name="$var" $disabled $required/>$value</textarea>);
        }
        elsif (grep { /^$type$/ } qw(checkbox)) {
            # false if $value is empty otherwise true 
            my $checked = $value ? 'checked' : '';
            return qq(<input type="$type" name="$var" value="true" $checked $disabled $required/>);
        }
        else { # no such type
            return "\$($var)";
        }
    }
}

true; # need to end with a true value
