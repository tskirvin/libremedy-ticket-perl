package Remedy::Form::Time;
our $VERSION = "0.12";
our $ID = q$Id: Remedy.pm 4743 2008-09-23 16:55:19Z tskirvin$;
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Time - per-ticket time logs

=head1 SYNOPSIS

    use Remedy::Time;

    # $remedy is a Remedy object
    my @worklog = Remedy::Time->read ('db' => $remedy, 
        'PARENT' => 'INC000000002371');
    for my $entry (@worklog) { print scalar $entry->print_text }

=head1 DESCRIPTION

Stanfor::Remedy::Unix::Time tracks individual work log entries for tickets as part
of the remedy database.  It is a sub-class of B<Stanford::Packages::Form>, so
most of its functions are described there.

=cut

##############################################################################
### Declarations
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

our @ISA = init_struct (__PACKAGE__);

##############################################################################
### Class::Struct
##############################################################################

=head1 FUNCTIONS

These 

=head2 B<Class::Struct> Accessors

=over 4

=item attach1, attach2, attach3, attach4, attach5 ($)

These list the five possible attachments per-worklog-entry.  Not yet well
supported.  These correspond to fields 'z2AF Work Log01' to 'zaAF Work Log 05'.

=item date_submit ($)

The date that the worklog was created.  Corresponds to field 

=item description ($)

=item details ($)

=item id ($)

=item number ($)

Incident number of the original ticket.  Corresponds to field 'Incident Number'.

=item map (%)

A 

=item parent ($)

=item submitter ($)

Address of the person who created this worklog entry.  Corresponds to field
'Work Log Submitter'.

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
    'id'          => 'Request ID',
    'submit_time' => 'Create Date',
    'number'      => 'Incident Number',
    'time_spent'  => 'Time Spent',
    'submitter'   => 'User Entering Time Spent',
}

=item print_text ()

Returns a short list of the salient points of the worklog entry - the
submitter, the submission date, the short description, and the actual text of
the worklog.

=cut

sub print_text {
    my ($self, %args) = @_;

    my @return = $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Time Spent (min)' => $self->time_spent || '(not set)',
        'Submitted By'     => $self->submitter,
        'Submitted Time'   => $self->submit_time,
    );

    return wantarray ? @return : join ("\n", @return, '');
}

=item table ()

'HPD:Time'

=cut

sub table { '+HPD:INC-SupportIndividualTimeLog' }

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
