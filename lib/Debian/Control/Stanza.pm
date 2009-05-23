=head1 NAME

Debian::Control::Stanza - single stanza of Debian source package control file

=head1 SYNOPSIS

    package Binary;
    use base 'Debian::Control::Stanza';
    use constant fields => qw( Package Depends Conflicts );

    1;

=head1 DESCRIPTION

Debian::Control::Stanza ins the base class for
L<Debian::Control::Stanza::Source> and L<Debian::Control::Stanza::Binary>
classes.

=cut

package Debian::Control::Stanza;

require v5.10.0;

use strict;

use base qw( Class::Accessor Tie::IxHash );

use Carp qw(croak);
use Debian::Dependencies;

=head1 FIELDS

Stanza fields are to be defined in the class method I<fields>. Tyically this
can be done like:

    use constant fields => qw( Foo Bar Baz );

Fields that are to contain dependency lists (as per L</is_dependency_list>
method below) are automatically converted to instances of the
L<Debian::Dependencies> class.

=cut

use constant fields => ();

sub import {
    my( $class ) = @_;

    $class->mk_accessors( $class->fields );
}

use overload '""' => \&as_string;

=head1 CONSTRUCTOR

=over

=item new

=item new( { field => value, ... } )

Creates a new L<Debian::Control::Stanza> object and optionally initializes it
with the supplied data. The object is hashref based and tied to L<Tie::IxHash>.

You may use dashes for initial field names, but these will be converted to
underscores:

    my $s = Debian::Control::Stanza::Source( {Build-Depends => "perl"} );
    print $s->Build_Depends;

=back

=cut

sub new {
    my $class = shift;
    my $init = shift || {};

    my $self = {};

    tie %$self, 'Tie::IxHash';
    bless $self, $class;

    while( my($k,$v) = each %$init ) {
        $k =~ s/-/_/g;
        $self->can($k)
            or croak "Invalid field given ($k)";
        $self->$k($v);
    }

    # initialize any dependency lists with empty placeholders
    for( $self->fields ) {
        if( $self->is_dependency_list($_) and not $self->$_ ) {
            $self->$_( Debian::Dependencies->new );
        }
    }

    return $self;
}

=head1 METHODS

=over

=item is_dependency_list($field)

Returns true if I<$field> contains a list of dependencies. By default returns true for the following fields:

=over

=item Build_Depends

=item Build_Depends_Indep

=item Build_Conflicts

=item Build_Conflicts_Indep

=item Depends

=item Conflicts

=item Enhances

=item Breaks

=item Pre_Depends

=item Recommends

=item Suggests

=back

=cut

our %dependency_list = map(
    ( $_ => 1 ),
    qw( Build-Depends Build-Depends-Indep Build-Conflicts Build-Conflicts-Indep
    Depends Conflicts Enhances Breaks Pre-Depends Recommends Suggests ),
);

sub is_dependency_list {
    my( $self, $field ) = @_;

    $field =~ s/_/-/g;

    return exists $dependency_list{$field};
}

=item is_comma_separated($field)

Returns true if the given field is to contain a comma-separated list of values.
This is used in stringification, when considering where to wrap long lines.

By default the following fields are flagged to contain such lists:

=over

=item All fields that contain dependencies (see above)

=item Uploaders

=item Provides

=back

=cut

our %comma_separated = map(
    ( $_ => 1 ),
    keys %dependency_list,
    qw( Uploaders Provides ),
);

sub is_comma_separated {
    my( $self, $field ) = @_;

    $field =~ s/_/-/g;

    return exists $comma_separated{$field};
}

=item get($field)

Overrides the default get method from L<Class::Accessor> with L<Tie::IxHash>'s
FETCH.

=cut

sub get {
    my( $self, $field ) = @_;

    $field =~ s/_/-/g;

    return ( tied %$self )->FETCH($field);
}

=item set( $field, $value )

Overrides the default set method from L<Class::Accessor> with L<Tie::IxHash>'s
STORE. In the process, converts I<$value> to an instance of the
L<Debian::Dependencies> class if I<$field> is to contain dependency list (as
determined by the L</is_dependency_list> method).

=cut

sub set {
    my( $self, $field, $value ) = @_;

    chomp($value);

    $field =~ s/_/-/g;

    $value = Debian::Dependencies->new($value)
        if not ref($value) and $self->is_dependency_list($field);

    return ( tied %$self )->STORE( $field,  $value );
}

=item as_string($width)

Returns a string representation of the object. Ready to be printed into a
real F<debian/control> file. Used as a stringification operator.

If non-zero I<$width> is given, the text is wrapped at that position. If no
I<$width> is given the text is wrapped at position 80. To disable wrapping,
supply a value of 0.

=cut

sub as_string
{
    my( $self, $width ) = @_;

    $width //= 80;

    my @lines;

    while( my($k,$v) = each %$self ) {
        next unless defined($v);
        next if $self->is_dependency_list($k) and "$v" eq "";

        my $line = "$k: $v";

        if( $self->is_comma_separated($k) ) {
            while( length($line) > $width and $line =~ /,/s ) {
                my $rest;
                while( length($line) > $width and $line =~ /,/s ) {
                    # chop-off the last entry
                    $line =~ /^(.+)\s*,\s*([^,]*)$/s;
                    $line = $1;
                    $rest = join( ', ', $2, $rest||() );
                }

                # at this point $line is under $width long (or can't be
                # shortened further)
                push @lines, $line . ( $rest ? ',' : '' );
                $line = " $rest" if $rest;
            }
        }
        push @lines, $line if $line;
    }

    return join( "\n", @lines ) . "\n";
}

=back

=head1 COPYRIGHT & LICENSE

Copyright (C) 2009 Damyan Ivanov L<dmn@debian.org>

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License version 2 as published by the Free
Software Foundation.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut

1;