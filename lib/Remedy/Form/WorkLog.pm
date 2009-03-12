package Remedy::Form::WorkLog;
our $VERSION = "0.12";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Form::Worklog - per-incident worklogs

=head1 SYNOPSIS

    use Remedy::Form::Worklog;

    # $remedy is a Remedy object
    foreach my $worklog ($remedy->read ('worklog', 'PARENT' => 
        'INC000000002371')) {
        print scalar $entry->print_text 
    }

=head1 DESCRIPTION

Remedy::Form::WorkLog manages the I<HPD:WorkLog> form in Remedy, which tracks  
emails and staff interaction with a given incident.                            

Remedy::Form::WorkLog is a sub-class of B<Remedy::Form>, registered as
I<worklog>.

=cut

##############################################################################
### Declarations #############################################################
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

our @ISA = init_struct (__PACKAGE__);
Remedy::Form->register ('worklog', __PACKAGE__);

##############################################################################
### Class::Struct ############################################################
##############################################################################

=head1 FUNCTIONS

These 

=head2 B<Class::Struct> Accessors

=over 4

=item id (I<Work Log ID>)

=item attach1 (I<z2AF Work Log01>)

=item attach2 (I<z2AF Work Log01>)

=item attach3 (I<z2AF Work Log01>)

=item attach4 (I<z2AF Work Log01>)

=item attach5 (I<z2AF Work Log01>)

These list the five possible attachments per-worklog-entry.  Not yet well
supported.  

=item date_submit (I<Work Log Submit Date>)

The date that the worklog was created.

=item description (I<Description>)

=item details (I<Detailed Description>)

=item number (I<Incident Number>)

Incident number of the original ticket.

=item submitter (I<Work Log Submitter>

Address of the person who created this worklog entry.

=item time_spent (I<Total Time Spent>)

In minutes.

=item type (I<Work Log Type>)

=back

=cut

sub field_map { 
    'id'                    => 'Work Log ID',
    'attach1'               => 'z2AF Work Log01',
    'attach2'               => 'z2AF Work Log02',
    'attach3'               => 'z2AF Work Log03',
    'attach4'               => 'z2AF Work Log04',
    'attach5'               => 'z2AF Work Log05',
    'date_submit'           => 'Work Log Submit Date',
    'description'           => 'Description',
    'details'               => 'Detailed Description',
    'number'                => 'Incident Number',
    'submitter'             => 'Work Log Submitter',
    'time_spent'            => 'Total Time Spent',
    'type'                  => 'Work Log Type',
}

##############################################################################
### Local Functions ##########################################################
##############################################################################

=head2 Local Functions

=over 4

=item attachments ()

Lists the names of the attachments connected with this worklog, separated with
semicolons, or 'none' if there are none.

=cut

sub attachments {
    my ($self) = @_;
    my @list;
    for my $i (qw(1 2 3 4 5)) {
        my $func = "attach$i";
        my $attach = $self->$func;
        if ($attach && ref $attach) { 
            push @list, $$attach{'name'};
        }
            
    }
    return scalar @list ? join ("; ", @list) : "none";
}

=back

=cut

##############################################################################
### Remedy::Form Overrides ###################################################
##############################################################################

=head2 B<Remedy::Form> Overrides

=over 4

=item field_map ()

=item limit_pre (ARGHASH)

=over 4

=item PARENT I<number>

If set, then we will just search based on the I<Incident Number> field.

=back

=cut

sub limit_pre {
    my ($self, %args) = @_;
    my $parent = $self->parent_or_die ();

    if (my $eid = $args{'PARENT'}) { return ('Incident Number' => $eid); }

    return %args;
}

=item print ()

Formats information about the worklog entry, including the submitter, the
submission date, the short description, and the actual text of the worklog.

=cut

sub print {
    my ($self, %args) = @_;

    my @return = $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Submitter'        => $self->submitter,
        'Date'             => $self->date_submit,
        'Description'      => $self->description,
        'Type'             => $self->type,
        'Time Spent (min)' => $self->time_spent || '(not set)',
        'Attachments'      => $self->attachments || 0);

    push @return, '', $self->format_text ({'prefix' => '  '},
        $self->details || "No text provided");

    return wantarray ? @return : join ("\n", @return, '');
}

=item table ()

=cut

sub table { 'HPD:WorkLog' }

=back

=cut

##############################################################################
### Final Documentation ######################################################
##############################################################################

=head1 TODO

Figure out a way to actaully extract the attachments, and present them in a
reasonable manner.

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
