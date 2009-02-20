package Remedy::Ticket;
our $VERSION = "0.10";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Ticket - [...]

=head1 SYNOPSIS

use Remedy::Ticket;

# $remedy is a Remedy object
[...]

=head1 DESCRIPTION

Stanfor::Remedy::Incident maps users (the B<User> table) to support groups
(B<Group>).

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
    'all'      => ['Remedy::Form::Task', 'Remedy::Form::Incident'],
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
use Lingua::EN::Inflect qw/inflect/;

use Remedy;
use Remedy::Ticket::Functions;

use Remedy::Form::Audit;
use Remedy::Form::Incident;
use Remedy::Form::People;
use Remedy::Form::Task;
use Remedy::Form::TicketGen;
use Remedy::Form::Time;
use Remedy::Form::WorkLog;

our @ISA; 
push @ISA, qw/Remedy/;

Remedy::Form->register ('ticket', $FORM{'all'});

##############################################################################
### Subroutines
##############################################################################

=head1 FUNCTIONS

=head2 Local Methods

=over 4

=item get (NUMBER)

=cut

sub get {
    my ($self, $number) = @_;
    my $logger  = $self->logger_or_die;

    $logger->all ("ticket_number ($number)");
    my $fullnum = $self->ticket_number ($number)
        or $logger->logdie ("invalid ticket number: $number");

    my $type = $self->ticket_type ($fullnum) 
        or $logger->logdie ("invalid ticket type: $fullnum");
    
    $logger->debug ("pulling data about '$fullnum'");
    my @tkt = $self->read ($type, 'number' => $fullnum);
    $logger->debug (sprintf ("%d entries", scalar @tkt));

    return unless scalar @tkt;
    return wantarray ? @tkt : $tkt[0];
}   

=item list (CONSTRAINTS)

=cut

sub list {}

=item close (TEXT)

=cut

sub close {
    my ($self, $text, %args) = @_;
    # $self->assign
}

=item assign () 

=cut

## need to set 'Support Company', 'Support Organization', 'Owner Group',
## 'Owner Group ID', 'Assignee'
sub assign  {
    my ($self, $number, %args) = @_;
    my $logger = $self->logger_or_die;

    my $group = $args{'group'};

    my %toset;

    if (my $user = defined $args{'user'}) { 
        $toset{'Assignee'} = $user;
    } elsif (exists $args{'user'}) {
        $toset{'Assignee'} = undef;
    }

    if (my $group = defined $args{'group'}) {
    } elsif (exists $args{'group'}) {
    }

    if (exists $args{'user'}) {
        my $user = $args{'user'};
        # $logger->
        my %person_search = ('SUNET ID' => $user);
        my @return = $self->read ('people', %person_search);
        unless (scalar @return) { 
            # $logg
        }
        $logger->logdie ("user '$user' does not belong to any groups")
            unless scalar @return;
        my @groups;
        foreach (@return) { push @groups, $_->group }

       # if (scalar @groups) {
       #     push @text, "in all member groups of '$user'";
       #     $hash{'groups'} = \@groups;
       # }
    }

    my @tickets = $self->get ($number);
    foreach my $tkt (@tickets) { 
        
    }
}

=item resolve (NUMBER, TEXT)

=cut

sub resolve {
    my ($self, $number, $text, @rest) = @_;
    return "no ticket number" unless $number;
    return "no resolution text" unless $text;
    return _run_on_tickets ($self, 'resolve', $number, $text, @rest);
}

=item set_status ()

=cut

sub set_status { 
    my ($self, $number, $status, @rest) = @_;
    return "no ticket number" unless $number;
    return "no status offered" unless $status;
    return _run_on_tickets ($self, 'set_status', $number, $status, @rest);
}

=item text (NUMBER, TYPE)

=cut

sub text { 
    my ($self, $number, $type) = @_;
    my $logger = $self->logger_or_die;

    $type ||= '';
    my @list = qw/primary requestor assignee description resolution worklog/;
    if    (lc $type eq 'debug')      { @list = qw/debug/            } 
    elsif (lc $type eq 'audit')      { @list = qw/primary audit/    } 
    elsif (lc $type eq 'worklog')    { @list = qw/primary worklog/  } 
    elsif (lc $type eq 'timelog')    { @list = qw/primary timelog/  } 
    elsif (lc $type eq 'summary')    { @list = qw/primary summary/  } 
    elsif (lc $type eq 'assign')     { @list = qw/primary assignee/ }
    elsif ($type =~ /^(all|full)$/i) { push @list, qw/audit time/   } 
    else                             { push @list, qw/summary/      } 
    $logger->debug ('text types: ' . join (', ', @list));

    local $@;
    my $tkt = eval { $self->get ($number) };
    $logger->logdie ("error loading '$number': $@") if $@ || !$tkt;

    return $tkt->print (@list);
}

sub worklog_add {}
sub timelog_add {}

=cut

    $tktdata{'1000000156'} = $text;                 # 'Resolution'
    $tktdata{'1000005261'} = time;                  # 'Resolution Date'
    $tktdata{'7'}          = 4;                     # 'Status' = "Resolved"
    $tktdata{'1000000215'} = 11000;                 # 'Reported Source'
    $tktdata{'1000000150'} = 17000;                 # "No Further Action Required"
    # Not doing 1000000642, "Time Spent"

=cut

=item assignee 

=cut

sub assignee {
    my ($self) = @_;
    return $self->format_email ($self->assignee_name, $self->assignee_sunet);
}

=item ticket_number (NUMBER)

Given I<NUMBER>, pads that into a valid incident number - that is, something
that begins with either INC, TAS, or HD0, with a length of 15 characters.  If
no such prefix is offered, we'll assume you want 'INC', as so:  

  990977        INC000000990977

Returns undef if nothing can be created.

=cut

sub ticket_number {
    my ($self, $num) = @_;
    return $num if $num && $num =~ /^(HD0|INC|TAS)/ && length ($num) == 15;
    $num ||= "";

    if ($num =~ /^(HD0|TAS|INC)(\d+)$/) {
        $num = $1    . ('0' x (15 - length ($num))) . $2;
    } elsif ($num =~ /^(\d+)/) {
        $num = 'INC' . ('0' x (12 - length ($num))) . $1;
    } else {
        return;
    }
    return $num;
}

=item ticket_type (NUMBER)


=cut

sub ticket_type {
    my ($self, $num) = @_;
    my $incident = $self->ticket_number ($num) || '';
    if    ($incident =~ /^INC/) { return 'incident' }
    elsif ($incident =~ /^TAS/) { return 'task'     }
    elsif ($incident =~ /^HD0/) { return 'order'    }
    else                        { return 'unknown'  } 
}

=item requestor

=cut

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
        push @return, ($audit->print);
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
        'Ticket'            => $self->inc_num       || "(none set)", 
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
        push @return, ($time->print);
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
        push @return, ($worklog->print);
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

=item worklog_create ()

Creates a new worklog entry, pre-populated with the date and the current
incident number.  You will still have to add other data.

=over 4

=back

=cut

sub worklog_create {
    my ($self, %args) = @_;
    return unless $self->inc_num;
    my $worklog = $self->create ('Remedy::Form::WorkLog', %args);
    $worklog->number ($self->number);
    $worklog->date_submit ($self->format_date (time));
    return $worklog;
}

=item timelog_create (TIME)

=cut

sub timelog_create {
    my ($self, %args) = @_;
    return unless $self->inc_num;
    my $timelog = $self->parent_or_die (%args)->create ('Remedy::Form::Time');
    $timelog->number ($self->number);
    return $timelog;
}

=back

=item table ()

=cut

sub table { 'HPD:Help Desk' }

=item name (FIELD)

=cut

sub name { 
    my ($self, $field) = @_;
    my $id = $self->field_to_id ($field);
    return $self->map->{$field};
}

=back

=cut

##############################################################################
### Internal Subroutines #####################################################
##############################################################################

sub _run_on_tickets {
    my ($self, $func, $number, @args) = @_;
    my $logger  = $self->logger_or_die;
    my $session = $self->session_or_die;

    $logger->debug ("getting tickets named '$number'");
    my @tickets = $self->get ($number);
    return "no matching ticket" unless scalar @tickets;
    my $errors = 0;
    foreach my $tkt (@tickets) { 
        my $tktnumber = $tkt->number;
        unless ($tktnumber) { 
            $logger->error ("no ticket number, skipping");
            $errors++;
            next;
        }
        $logger->debug ("running '$func' on '$tktnumber'");

        if (my $error = $tkt->$func (@args)) {
            $logger->error ("$func: $error");
            $errors++;
            next;
        }

        $logger->debug ("saving '$tktnumber'");

        if (my $error = $tkt->save) { 
            $logger->error ("could not save '$tktnumber': ", $session->error);
            $errors++;
        } else {
            $logger->info ("successfully saved '$tktnumber'");
            
        }
    }
    
    my $text = sprintf ("%s out of %s", 
        inflect ("NUM($errors) PL_N(error)"),
        inflect (sprintf ("NUM(%d) PL_N(ticket)", scalar @tickets)));
    $logger->info ($text);
    return $text if $errors;
    return "$errors errors" if $errors;
    return;
}


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
