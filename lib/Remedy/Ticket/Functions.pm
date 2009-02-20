package Remedy::Ticket::Functions;
our $VERSION = "0.10";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Ticket::Functions - [...]

=head1 SYNOPSIS

use Remedy::Ticket;

# $remedy is a Remedy object
[...]

=head1 DESCRIPTION

Remedy::Ticket::Functions provides additional functions for B<Remedy::Form>
objects that inherit from B<Remedy::Ticket>.

=cut

##############################################################################
### Configuration 
##############################################################################

=head1 VARIABLES

These variables primarily hold human-readable translations of the status,
impact, etc of the ticket; but there are a few other places for customization.

=over 4

=item %TEXT

=cut

our %TEXT = ('debug' => \&Remedy::Form::debug_text);

our %FORM = (
    'all'      => ['Remedy::Form::Incident', 'Remedy::Form::Task'],
    'incident' => 'Remedy::Form::Incident',
    'task'     => 'Remedy::Form::Task',
);
    # might add Remedy::Form::Order

=back

=cut

##############################################################################
### Declarations
##############################################################################

use strict;
use warnings;

use Class::Struct;

use Remedy;
use Remedy::Ticket::Functions;

use Remedy::Form::Audit;
use Remedy::Form::Incident;
use Remedy::Form::Task;
use Remedy::Form::TicketGen;
use Remedy::Form::Time;
use Remedy::Form::WorkLog;

##############################################################################
### Subroutines
##############################################################################

=head1 FUNCTIONS

=head2 Local Methods

=over 4

=item add_time (MINUTES, TEXT)

=item add_worklog (TEXT)

=item assign (USER, GROUP)

=item list (TYPE)

=item resolve (TEXT)

=item set_status (STATUS)

=cut

sub add_time    { "not implemented" }
sub add_worklog { "not implemented" }
sub assign      { "not implemented" }
sub list        { "not implemented" }
sub resolve     { "not implemented" }
sub set_status  { "not implemented" }

=item get_incnum (ARGHASH)

Finds or creates the incident number for the current incident.  If we do not
already have one set and stored in B<number ()>, then we will create one using
B<Remedy::TicketGen ().

=over 4

=item description (TEXT)

=item user (USER)

=back

=cut

sub get_incnum {
    my ($self, %args) = @_;
    my ($parent, $session) = $self->parent_and_session (%args);

    return $self->number if defined $self->number;
    if (! $self->ticketgen) {
        my $ticketgen = $parent->create ('Remedy::Form::TicketGen') 
            or $self->error ("couldn't create new ticket number: " . $session->error );
        $ticketgen->description ($args{'description'} || $self->default_desc);
        $ticketgen->submitter ($args{'user'} || $parent->config->remedy_user);

        print scalar $ticketgen->print_text, "\n";
        $ticketgen->save ('db' => $parent) 
            or $self->error ("couldn't create new ticket number: $@");
        $ticketgen->reload;
        $self->ticketgen ($ticketgen);
        $self->number ($ticketgen->number);
    }

    return $self->number;
}

sub default_desc { "Created by " . __PACKAGE__ }

=item assignee 

=cut

sub assignee {
    my ($self) = @_;
    return $self->format_email ($self->assignee_name, $self->assignee_sunet);
}

sub requestor {
    my ($self) = @_;
    my $name = join (" ", $self->requestor_first_name || '',
                          $self->requestor_last_name || '');
    return $self->format_email ($name, $self->requestor_email || '');
}

=item text_assignee ()

=cut

sub text_assignee {
    my ($self) = @_;
    my @return = "Ticket Assignee Info";
    push @return, $self->format_text_field ( 
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Group'         => $self->assignee_group || "(unassigned)",
        'Name'          => $self->assignee,
        'Last Modified' => $self->date_modified,
    );
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'assignee'} = \&text_assignee;

=item text_audit

=cut

sub text_audit {
    my ($self, %args) = @_;
    my ($count, @return);
    foreach my $audit ($self->audit (%args)) { 
        push @return, '' if $count;
        push @return, "Audit Entry " . ++$count;
        push @return, ($audit->print_text);
    }
    return "No Audit Information" unless $count;
    unshift @return, "Audit Entries ($count)";
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'audit'} = \&text_audit;

=item text_description ()

=cut

sub text_description {
    my ($self) = @_;
    my @return = "User-Provided Description";
    push @return, $self->format_text ({'prefix' => '  '},
        $self->description || '(none)');
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'description'} = \&text_description;

=item text_primary ()

=cut

sub text_primary {
    my ($self, %args) = @_;
    my @return = "Primary Ticket Information";
    push @return, $self->format_text_field ( 
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Ticket'            => $self->number       || "(none set)", 
        'Summary'           => $self->summary,
        'Status'            => $self->status        || '(not set/invalid)',
        'Status Reason'     => $self->status_reason || '(not set)',
        'Submitted'         => $self->date_submit,
        'Urgency'           => $self->urgency       || '(not set)',
        'Priority'          => $self->priority      || '(not set)',
        'Incident Type'     => $self->incident_type || "(none)",
    );

    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'primary'} = \&text_primary;

=item text_requestor ()

=cut

sub text_requestor {
    my ($self) = @_;
    my @return = "Requestor Info";
    
    push @return, $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'SUNet ID'    => $self->sunet || "(none)",
        'Name'        => $self->requestor,
        'Phone'       => $self->requestor_phone,
        'Affiliation' => $self->requestor_affiliation,
    );
    
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'requestor'} = \&text_requestor;

sub text_resolution {
    my ($self) = @_;
    my @return = "Resolution";

    my $resolution= $self->resolution || return;
    push @return, $self->format_text_field ( 
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Date'              => $self->date_resolution,
    );
    push @return, '', $self->format_text ({'prefix' => '  '}, $resolution);

    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'resolution'} = \&text_resolution;

sub text_summary {
    my ($self, %args) = @_;
    my @return = "Summary Ticket Information";
    my @timelog = $self->timelog (%args);
    my @worklog = $self->worklog (%args);
    my @audit   = $self->audit   (%args);
    push @return, $self->format_text_field ( 
        {'minwidth' => 20, 'prefix' => '  '}, 
        'WorkLog Entries' => scalar @worklog,
        'TimeLog Entries' => scalar @timelog,
        'Audit Entries'   => scalar @audit,
        'Time Spent (mins)' => $self->total_time_spent || 0,
    );
    
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'summary'} = \&text_summary;

=item text_timelog ()

=cut

sub text_timelog {
    my ($self, %args) = @_;
    my (@return, $count);
    foreach my $time ($self->timelog (%args)) { 
        push @return, '' if $count;
        push @return, "Time Entry " . ++$count;
        push @return, ($time->print_text);
    }
    return "No TimeLog Entries";
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'timelog'} = \&text_timelog;

=item text_worklog ()

=cut

sub text_worklog {
    my ($self, %args) = @_;
    my (@return, $count);
    foreach my $worklog ($self->worklog (%args)) { 
        push @return, '' if $count;
        push @return, "Work Log Entry " . ++$count;
        push @return, ($worklog->print_text);
    }
    return "No WorkLog Entries" unless $count;
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'worklog'} = \&text_worklog;

=back

=cut

##############################################################################
### Related Classes
##############################################################################

=head2 Related Classes

=over 4

=item audit ()

=cut

sub audit {
    my ($self, %args) = @_;
    $self->related_by_id ('audit', 'PARENT' => $self->id, %args);
}

=item worklog (ARGHASH)

=cut

sub worklog {
    my ($self, %args) = @_;
    $self->related_by_id ('worklog', 'PARENT' => $self->number, %args);
}

=item timelog ()

=cut

sub timelog {
    my ($self, %args) = @_;
    $self->related_by_id ('Remedy::Form::Time', 'PARENT' => $self->number, %args);
}

=item worklog_create ()

Creates a new worklog entry, pre-populated with the date and the current
incident number.  You will still have to add other data.

=over 4

=back

=cut

sub worklog_create {
    my ($self, %args) = @_;
    return unless $self->number;
    my $worklog = $self->create ('Remedy::WorkLog', %args); # TODO: 'or die'
    $worklog->number ($self->number);
    $worklog->date_submit ($self->format_date (time));
    return $worklog;
}

=item timelog_create (TIME)

=cut

sub timelog_create {
    my ($self, %args) = @_;
    return unless $self->number;
    my $timelog = $self->create ('Remedy::Time', %args);
    $timelog->number ($self->number);
    return $timelog;
}

=back

=cut

=item limit (ARGHASH)



=over 4 

=item assigned_user (USER)

If not offered, 'Assigned Login ID' is set to the value of 'username'
(defaults to 

=item groups (GROUPS)

Given a list of groups I<GROUPS> (either an arrayref containing a single group
name, or a single group name), creats the 'OR' separated list of possible
groups that the field F<Assigned Group> could belong to.  

=item 'Assigned Support Company' (<ITEM>), 

=item 'Assigned Support Organization' (<ITEM>)

=item 'Assigned Support Group' (<ITEM>)

Taken from 

=back

Once all checks have been done, then we'll get additional limiting infromation
from 

=cut

sub summary_text {
    my ($self) = @_;

    my $number = $self->number;
       $number =~ s/^INC0+//;
    my $request = $self->sunet || 'NO_SUNETID';
       $request =~ s/NO_SUNETID|^\s*$/(none)/g;
    my $assign  = $self->assignee_sunet || "(none)";
    my $group   = $self->assignee_group || "(none)";
    my $summary = $self->summary || "";
    map { s/\s+$// } $summary, $group, $assign, $request;

    my $update = $self->date_modified;
    my $create = $self->date_submit;

    my @return;
    push @return, sprintf ("%-8s   %-8s   %-8s   %-32s  %12s", 
        $number, $request, $assign, $group, $self->status || '(not set)');
    push @return, sprintf ("  Created: %23s        Updated: %23s", $create, $update);
    push @return, sprintf ("  Summary: %s", $summary);

    return wantarray ? @return : join ("\n", @return, '');
}

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
