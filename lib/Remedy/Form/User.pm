package Remedy::Form::User;
our $VERSION = "0.12";
our $ID = q$Id: Remedy.pm 4743 2008-09-23 16:55:19Z tskirvin$;
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::User - ticket-generation table

=head1 SYNOPSIS

    use Remedy;
    use Remedy::User;

    [...]

=head1 DESCRIPTION

Remedy::User tracks [...] 
It is a sub-class of B<Stanford::Packages::Form>, so
most of its functions are described there.

=cut

##############################################################################
### Declarations
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

use Remedy::Form::People;

our @ISA = init_struct (__PACKAGE__);
Remedy::Form->register ('user', __PACKAGE__);

##############################################################################
### Class::Struct
##############################################################################

=head1 FUNCTIONS

These 

=head2 B<Class::Struct> Accessors

=over 4

=item description ($)

=item incnum ($)

=item submitter ($)

=back

=cut

##############################################################################
### Local Functions 
##############################################################################

=head2 B<Remedy::Form Overrides>

=over 4

=item field_map

=cut

sub field_map { 
    'netid'      => "Login Name",
    'name'       => "Full Name",
    'group_list' => 'Group List',
}

=item name ()

=cut

sub print_text {
    my ($self) = @_;
    my $user = $self->netid;
    return unless $user;
    my @groups = $self->groups;

    my @return = "User information for '$user'";
    
    push @return, $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Full Name'   => $self->name,
        'SUNet ID'    => $self->netid || "(none)",
        'Groups'      => scalar @groups || "(none)",    # should be the number of groups
    );
    foreach my $group (@groups) {
        push @return, "    $group"
    }
    return wantarray ? @return : join ("\n", @return, '');
}

sub groups { 0 }    # actually parse SGA to get this information

=item table ()

=cut

sub table { 'User' }

=back

=cut

###############################################################################
### Final Documentation
###############################################################################

=head1 REQUIREMENTS

B<Class::Struct>, B<Remedy::Form>

=head1 SEE ALSO

Remedy(8)

=head1 HOMEPAGE

TBD.

=head1 AUTHOR

Tim Skirvin <tskirvin@stanford.edu>

=head1 LICENSE

Copyright 2008-2009 Board of Trustees, Leland Stanford Jr. University

This program is free software; you may redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
