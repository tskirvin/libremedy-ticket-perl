package Remedy::Form::Incident;
our $VERSION = "0.50";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Form::Incident - incidents in remedy

=head1 SYNOPSIS

    use Remedy::Form::Incident;

    # $remedy is a Remedy object
    foreach my $inc ($remedy->read ('incident', 'all' => 1)) {
        print scalar $inc->print;
    }

=head1 DESCRIPTION

Remedy::Form::Incident manages the I<HPD:Help Desk> form in Remedy, which
tracks all user incidents (basically, trouble tickets).  

Remedy::Form::Incident is a sub-class of B<Remedy::Form>, registered as
'incident'.

=cut

##############################################################################
### Configuration ############################################################
##############################################################################

=head1 VARIABLES

=over 4

=item @TEXT_TYPES 

Used by B<print ()> to decide what kinds of text information we'll print by
default (therefore, what is passed on to B<text ()>.  Defaults to:

    primary requestor assignee description resolution

=cut

our @TEXT_TYPES = qw/primary requestor assignee description resolution/;

=back

=cut

##############################################################################
### Declarations #############################################################
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

use Remedy::Form::Audit;
use Remedy::Form::TicketGen;
use Remedy::Form::WorkLog;

use Remedy::Ticket;

our @ISA = init_struct (__PACKAGE__, 'ticketgen' => 'Remedy::Form::TicketGen');
Remedy::Form->register ('incident', __PACKAGE__);

##############################################################################
### Subroutines ##############################################################
##############################################################################

=head1 FUNCTIONS

=head2 Local Methods

=over 4

=item assign (ARGHASH) 

Assigns an incident to a group and/or user.  Based on how much information we
get in I<ARGHADH>, there are four separate paths that this can take:

    user and group      adjust both user and group
    user, no group      keep the current group, adjust the user
    group, no user      adjust the group, clear the user
    neither             exit immediately

Therefore, one of the two items from I<ARGHASH> must be set:

=over 4

=item group I<GROUP>

Support group name.

=item user I<USER>

NetID of a user.

=back

This function works with the following fields:

=over 4

=item Assignee

=item Assignee Login ID

These come from the Support Group Assocation (B<Remedy::Form::SGA>) form
associated with the support group and the user.

=item Assigned Group

=item Assigned Group ID

=item Assigned Group Uses OLA

=item Owner Group

=item Owner Group ID

=item Shifts Flag

=item z1D Assigned Group Role

=item z1D Assigned Group Uses SLA

All of these come from the Support Group (B<Remedy::Form::SupportGroup>) form.

=back

=cut

sub assign  {
    my ($self, %args) = @_;
    my $logger = $self->logger_or_die ();

    return "no assignment changes offered" 
        unless (exists $args{'user'} || exists $args{'group'});

    my %toset;

    my $group = $args{'group'};
    $group ||= $self->get ('Owner Group');
    return 'no known group' unless $group;

    $logger->debug ("pulling support group information about '$group'");
    my $sg = $self->read ('supportgroup', 'Support Group Name' => $group);
    return "no matching support group for '$group'" unless $sg;

    ## Populate the initial fields that Business Logic Requires.
    $toset{'Owner Group'}                 = $sg->name;
    $toset{'Owner Group ID'}              = $sg->id;
    $toset{'z1D Assigned Group Uses SLA'} = $sg->get ('Uses SLA');
    $toset{'Assigned Group Uses OLA'}     = $sg->get ('Uses OLA');
    $toset{'z1D Assigned Group Role'}     = $sg->get ('Support Group Role');
    $toset{'Shifts Flag'}                 = $sg->get ('Shifts Flag');

    my $user  = $args{'user'};
    if ($user) { 
        $logger->debug ("confirming '$user' is in group '$group'");
        my %search = ('Support Group ID' => $sg->id, 'Login ID' => $user);
        if (my $sga = $self->read ('sga', %search)) {
            $toset{'Assignee'}          = $sga->get ('Full Name');
            $toset{'Assignee Login ID'} = $sga->get ('Login ID');
            $toset{'Assigned Group'}    = $sg->name;
            $toset{'Assigned Group ID'} = $sg->id;
        } else { 
            $logger->warn ("user '$user' is not in group '$group'");
            return "user '$user' is not in group '$group'";
        } 
    } else {
        $logger->debug ("no assigned person");
        $toset{'Assignee Login ID'} = undef;
        $toset{'Assignee'}          = undef;
    }

    $self->set (%toset);
    return;
}

=item resolve (TEXT, [ARGHASH])

Resolves an incident - that is, sets its status to I<Resolved>, sets a status
reason of "No Further Action Required", adds resolution text I<TEXT>, and sets
a resolution date.

Arguments we accept through I<ARGHASH> (all optional):

=over 4

=item time I<TIMESTAMP>

Sets the time for ticket resolution.  Defaults to the current time; can be
either seconds-since-epoch or a parseable string.

=item timespent I<MINS>

How many minutes were spent working on this ticket?  We'll add this on with
B<time_add()>.

=item user I<USER>

If offered, and this ticket is not currently assigned, we will assign the 
ticket to this user before we resolve the ticket.

=back

=cut

sub resolve {
    my ($self, $text, %args) = @_;
    return 'no resolution text offered' unless defined $text;

    my $user = $args{'user'} || '';
    if (my $time = $args{'timespent'}) { 
        $self->time_add ($time, $user);
    }
    $self->assign ('user' => $user) if ($user && !$self->assignee);

    return $self->set_status ('Resolved',
        'Status_Reason'   => "No Further Action Required", 
        'Resolution'      => $text, 
        'Estimated Resolution Date' => $args{'time'} || time);
}

=item set_status (STATUS)

Sets the status of the incident to the offered I<STATUS>.  Note that we do not
check to see whether the status is valid at this step; this will happen when we
try to save the ticket.

=cut

sub set_status {
    my ($self, $status, @extra) = @_;
    return 'no status offered' unless $status;
    return $self->set ('Status' => $status, @extra);
}

=item time_add (TIME [, USER])

Updates the 'Time Spent' fields.  Depends on some Stanford-specific business
logic, which creates an entry in form I<+HPD:INC-SupportIndividualTimeLog>
based on I<TIME> (an integer number of minutes) and I<USER> (an optional
username that added the time; defaults to the user connected to the database);
this in turn updates the I<Total Time Spent (min)> field in its parent entry.

=cut

sub time_add { 
    my ($self, $time, $user) = @_;
    return 'no time to add' unless $time;
    return $self->set ('zTmpUserTimeSpent' => $user || '',
                       'Time Spent (min)'  => $time);
}

=item generate_number (ARGHASH)

Finds the incident number for the current incident.  if we do not already
have one set and stored in B<number ()>, then we will create one using
B<Remedy::Form::TicketGen ()>.

=over 4

=item description (TEXT)

=item user (USER)

=back

Not well tested.  In fact, consider this a stub for now.

=cut

sub generate_number {
    my ($self, %args) = @_;
    my $parent = $self->parent_or_die ();

    return $self->number if defined $self->number;
    if (! $self->ticketgen) {
        my %args;

        my $ticketgen = $self->create ('Remedy::Form::TicketGen') 
            or $self->error ("couldn't create new ticket number");
        $ticketgen->description ($args{'description'} || $self->default_desc);
        $ticketgen->submitter ($args{'user'} || $parent->config->remedy_user);

        print scalar $ticketgen->print, "\n";
        $ticketgen->save or $self->error 
            ("couldn't create new ticket number: $@");
        $ticketgen->reload;

        $self->ticketgen ($ticketgen);
        $self->number ($ticketgen->number);
    }

    return $self->number;
}

sub default_desc { "created by " . __PACKAGE__ }

=back

=cut

##############################################################################
### Text Generation ##########################################################
##############################################################################

=head2 Text Generation

These methods generate nicely formatted strings (or arrays of lines, depending
on context) for simple printing.

=over 4

=item text (ARRAY)

Invokes the rest of the B<text_*> subroutines, based on the contents of
I<ARRAY>.  

=cut

our %TEXT = ();
sub text {
    my ($self, @list) = @_;

    my @return;
    foreach (@list) { 
        next unless my $func = $TEXT{$_};
        my $text = scalar $self->$func;
        push @return, $text if defined $text;
    }

    return wantarray ? @return : join ("\n", @return, '');
}

=item text_assignee ()

Returns the assigned group, assigned user, and date of last modification.

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

Returns a count of the number of related audit entries, as well as a summary of
their contents (from B<Remedy::Form::Audit>).

=cut

sub text_audit {
    my ($self, %args) = @_;
    my ($count, @return);
    foreach my $audit ($self->audit (%args)) { 
        push @return, '' if $count;
        push @return, "Audit Entry " . ++$count;
        push @return, ($audit->print);
    }
    return "No Audit Information" unless $count;
    unshift @return, "Audit Entries ($count)";
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'audit'} = \&text_audit;

=item text_debug ()

Wrapper for B<Remedy::Form::debug_pretty ()>.

=cut

sub text_debug {
    my ($self) = @_;
    my @return = "Debugging Information";
    push @return, $self->debug_pretty;
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'debug'} = \&text_debug;

=item text_description ()

Nicely formats the user-provided description.

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

Returns the basic information about the incident - its public incident number,
the short summary of its ocntents, its current status (and the reason for
that), when it was submitted, its urgency and priority, and the type of
incident.

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

Offers information about the person that submitted the ticket - SUNet ID, Name,
Phone, and Affilation.

=cut

sub text_requestor {
    my ($self) = @_;
    my @return = "Requestor Info";
    
    push @return, $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'SUNet ID'    => $self->netid || "(none)",
        'Name'        => $self->requestor,
        'Phone'       => $self->requestor_phone,
        'Affiliation' => $self->requestor_affiliation,
    );
    
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'requestor'} = \&text_requestor;

=item text_resolution ()

Offers information about the resolution of the ticket - the date of resolution,
and the actual resolution text. 

If the ticket has not been resolved, returns nothing.

=cut

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

=item text_summary ()

A final summart of what we know about the ticket - the number of worklog
entries, audit entries, and amount of time spent on the ticket.

=cut

sub text_summary {
    my ($self, %args) = @_;
    my @return = "Summary Ticket Information";
    my @worklog = $self->worklog (%args);
    my @audit   = $self->audit   (%args);
    push @return, $self->format_text_field ( 
        {'minwidth' => 20, 'prefix' => '  '}, 
        'WorkLog Entries' => scalar @worklog,
        'Audit Entries'   => scalar @audit,
        'Time Spent (mins)' => $self->total_time_spent || 0,
    );
    
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'summary'} = \&text_summary;

=item text_short ()

A short description of the whole ticket, suitable for printing as part of
a list.  This includes the ticket number, the assigned user and group, its
current status, the short content summary, and the dates that the ticket was
modified and submitted.

=cut

sub text_short {
    my ($self) = @_;

    my $number = $self->number;
       $number =~ s/^INC0+//;
    my $request = $self->netid || 'NO_SUNETID';
       $request =~ s/NO_SUNETID|^\s*$/(none)/g;
    my $assign  = $self->assignee_netid || "(none)";
    my $group   = $self->assignee_group || "(none)";
    my $summary = $self->summary || "";
    map { s/\s+$// } $summary, $group, $assign, $request;

    my $update = $self->date_modified;
    my $create = $self->date_submit;

    my @return;
    push @return, sprintf ("%-8s  %-13.13s  %-8s %-32s %12s", 
        $number, $request, $assign, $group, $self->status || '(not set)');
    push @return, sprintf ("  Created: %s   Updated: %s", $create, $update);
    push @return, sprintf ("  Summary: %s", $summary);

    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'short'} = \&text_short;

=item text_worklog ()

Returns a count of the number of related worklog entries, as well as a summary
of their contents (from B<Remedy::Form::WorkLog>).

=cut

sub text_worklog {
    my ($self, %args) = @_;
    my (@return, $count);
    foreach my $worklog ($self->worklog (%args)) { 
        push @return, '' if $count;
        push @return, "Work Log Entry " . ++$count;
        push @return, ($worklog->print);
    }
    return "No WorkLog Entries" unless $count;
    return wantarray ? @return : join ("\n", @return, '');
}
$TEXT{'worklog'} = \&text_worklog;

=back

Additionally, we have a couple of functions to make pretty text versions 
of information stored in this form, which are used by the above text functions.

=over 4

=item assignee 

Creates an email string out of the assignee name and netid.

=cut

sub assignee {
    my ($self) = @_;
    return $self->format_email ($self->assignee_name, $self->assignee_netid);
}

=item requestor

Creates an email string out of the requestor first name, last name, and email.

=cut

sub requestor {
    my ($self) = @_;
    my $name = join (" ", $self->requestor_first_name || '',
                          $self->requestor_last_name || '');
    return $self->format_email ($name, $self->requestor_email || '');
}

=back

=cut

##############################################################################
### Related Classes ##########################################################
##############################################################################

=head2 Related Classes

=over 4

=item audit ()

Returns an array of audit entries (I<Remedy::Form::Audit>) related to the
incident number of the current object.

=cut

sub audit {
    my ($self, %args) = @_;
    $self->related_by_id ('audit', 'PARENT' => $self->id, %args);
}

=item worklog ()

Returns an array of worklog entries (I<Remedy::Form::WorkLog>) related to the
incident number of the current object.

=cut

sub worklog {
    my ($self, %args) = @_;
    $self->related_by_id ('worklog', 'PARENT' => $self->number, %args);
}

=item worklog_create ()

Creates a new worklog entry, pre-populated with the date and the current
incident number.  You will still have to add other data.

=cut

sub worklog_create {
    my ($self, %args) = @_;
    return unless $self->number;
    my $worklog = $self->create ('Remedy::Form::WorkLog', %args);
    $worklog->number ($self->number);
    $worklog->date_submit (time);
    return $worklog;
}

=back

=cut

##############################################################################
### Class::Struct ############################################################
##############################################################################

=head1 FUNCTIONS

=head2 B<Class::Struct> Accessors

=over 4

=item id (I<Entry ID>)

Internal ID of the entry.

=item assignee_group (I<Assigned Group>)

=item assignee_name (I<Assignee>)

=item assignee_netid (I<Assignee Login ID>)

=item date_modified (I<Last Modified Date>)

=item date_resolution (I<Estimated Resolution Date>)

=item date_submit (I<Submit Date>)

=item description (I<Detailed Decription>)

=item impact (I<Impact>)

=item incident_type (I<Incident Type>)

=item netid (I<SUNet ID+>)

=item number (I<Incident Number>)

=item priority (I<Priority>)

=item requestor_affiliation (I<SU Affiliation_chr>)

=item requestor_email (I<Requester Email_chr>)

=item requestor_first_name (I<First Name>)

=item requestor_last_name (I<Last Name>)

=item requestor_phone (I<Phone Number>)

=item resolution (I<Resolution>)

=item status_reason (I<Status_Reason>)

=item status (I<Status>)

=item summary (I<Description>)

=item time_spent (I<Time Spent (min)>)

=item total_time_spent (I<Total Time Spent (min)>)

=item urgency (I<Urgency>)

=back

=cut

sub field_map { 
    'id'                    => "Entry ID",
    'assignee_group'        => "Assigned Group",
    'assignee_name'         => "Assignee",
    'assignee_netid'        => "Assignee Login ID",
    'date_modified'         => "Last Modified Date",
    'date_resolution'       => "Estimated Resolution Date",
    'date_submit'           => "Submit Date",
    'description'           => "Detailed Decription",
    'impact'                => "Impact",
    'incident_type'         => "Incident Type",
    'netid'                 => "SUNet ID+",
    'number'                => "Incident Number",
    'priority'              => "Priority",
    'requestor_affiliation' => "SU Affiliation_chr",
    'requestor_email'       => "Requester Email_chr",
    'requestor_first_name'  => "First Name",
    'requestor_last_name'   => "Last Name",
    'requestor_phone'       => "Phone Number",
    'resolution'            => "Resolution",
    'status_reason'         => "Status_Reason",
    'status'                => "Status",
    'summary'               => "Description",
    'time_spent'            => "Time Spent (min)",
    'total_time_spent'      => "Total Time Spent (min)",
    'urgency'               => "Urgency",
}

##############################################################################
### Remedy::Form Overrides ###################################################
##############################################################################

=head2 B<Remedy::Form> Overrides

=over 4

=item limit_pre (ARGHASH)

=over 4

=item type I<TYPE>

If this is set to something other than 'incident', 'all', or '%', then return
immediately; we're searching for the wrong kind of data.  If it is set to one
of those, then delete it now.

=item number I<NUMBER>

We are just looking for I<Incident Number> I<NUMBER>.  

=item extra

=item groups

Takes an arrayref of group names that we'll search the 'Assigned Group' field
for.  

=item status

The status of the ticket.  Does different things by value:

=over 2

=item open

Less than I<Resolved>.

=item closed

I<Resolved> or greater.

=item (other)

Just passed to the 'Status' field directly.

=back

=item assigned_group 

Only search for the assigned group.

=item assigned_user

=item submitted_user

=item unassigned

=item last_modify_before

=item submit_before

=back

=cut

sub limit_pre {
    my ($self, %args) = @_;
    my $parent = $self->parent_or_die ();
    my $config = $parent->config_or_die ('no configuration');

    if (my $type = $args{'type'}) {
        return unless $type =~ /^(incident|all|%)$/i;
        delete $args{'type'};
    }   

    if (my $number = $args{'number'}) { return ('Incident Number' => $number) }

    $args{'Assigned Support Company'}      ||= $config->company   || "%";
    $args{'Assigned Support Organization'} ||= $config->sub_org   || "%";
    $args{'Owner Group'}                   ||= $config->workgroup || "%";

    my %fields = $self->fields (%args);

    my @extra;

    if (my $extra = $args{'extra'}) { 
        @extra = ref $extra ? @$extra : $extra;
        delete $args{'extra'};
    }

    if (my $groups = $args{'groups'}) {
        if (my $id = $fields{'Assigned Group'}) {
            my @list;
            foreach (ref $groups ? @$groups : $groups) { 
                my $name = $_->name;
                push @list, "'$id' = \"$name\"";
            }
            push @extra, ('(' . join (" OR ", @list) . ')')
                if scalar @list;
            delete $args{'groups'};
        }
    }

    if (my $group = $args{'assigned_group'}) { 
        $args{'Assigned Group'} = $group;
        delete $args{'assigned_group'} ;
    }

    if (my $status = lc $args{'status'}) { 
        if    ($status eq 'open')   { $args{'Status'} = '-Resolved'     }
        elsif ($status eq 'closed') { $args{'Status'} = '+=Resolved'    }
        else                        { $args{'Status'} = $args{'status'} }
        delete $args{'status'};
    } 

    if (my $user_assign = $args{'assigned_user'}) { 
        $args{'Assignee Login ID'} = $user_assign;
        delete $args{'assigned_user'};
    } else { 
        $args{'Assignee Login ID'} = '%';
    }

    if (my $user_submit = $args{'submitted_user'}) { 
        $args{'SUNet ID+'} = $user_submit;
        delete $args{'submitted_user'};
    }

    if ($args{'unassigned'}) { 
        $args{'Assignee Login ID'} = undef;
        delete $args{'unassigned'};
    }

    if (my $modify = $args{'last_modify_before'}) { 
        $args{'Last Modified Date'} = "-$modify";
        delete $args{'last_modify_before'};
    }

    if (my $create = $args{'submit_before'}) { 
        $args{'Submit Date'} = "-$create";
        delete $args{'submit_before'};
    }

    if (scalar @extra) { $args{'extra'} ||= [@extra] }

    return %args;
}


=item print ()

=cut

sub print { 
    my ($self, @types) = @_;
    @types = @TEXT_TYPES unless scalar @types;
    $self->text (@types);
}


=item table ()

=cut

sub table { 'HPD:Help Desk' }

=back

=cut

###############################################################################
### Final Documentation
###############################################################################

=head1 REQUIREMENTS

B<Remedy::Ticket>, B<Class::Struct>, B<Remedy::Form>, Form::Audit>,
B<Remedy::B<Remedy::Form::TicketGen>, B<Remedy::Form::WorkLog>

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
