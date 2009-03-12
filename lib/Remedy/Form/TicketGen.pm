package Remedy::Form::TicketGen;
our $VERSION = "0.50";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Form::TicketGen - ticket-generation table

=head1 SYNOPSIS

    use Remedy::Form::TicketGen;

    # $remedy is a Remedy object
    foreach my $tktg ($remedy->read ('ticketgen', 'all' => 1)) {
        print scalar $tktg->print;
    }

=head1 DESCRIPTION

Remedy::Form::TicketGen manages the I<HPD:CFG Ticket Num Generator> form in
Remedy, which is used solely to create public ticket numbers for incidents.

Remedy::Form::TicketGen is a sub-class of B<Remedy::Form>, registered as
I<ticketgen>.

=cut

##############################################################################
### Declarations #############################################################
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

our @ISA = init_struct (__PACKAGE__);
Remedy::Form->register ('ticketgen', __PACKAGE__);

##############################################################################
### Class::Struct Accessors ##################################################
##############################################################################

=head1 FUNCTIONS

=head2 B<Class::Struct> Accessors

=over 4

=item description (I<Short Description>)

=item inc_num (I<Incident Number>

=item status (I<Status>)

=item submitter (I<Submitter>)

=back

=cut

sub field_map {
    'description' => "Short Description",
    'inc_num'     => "Incident Number",
    'status'      => "Status",
    'submitter'   => "Submitter",
}

##############################################################################
### Remedy::Form Overrides ###################################################
##############################################################################

=head2 B<Remedy::Form> Overrides

=over 4

=item field_map ()

=item table ()

=cut

sub table { 'HPD:CFG Ticket Num Generator' }

=back

=cut

##############################################################################
### Final Documentation ######################################################
##############################################################################

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
