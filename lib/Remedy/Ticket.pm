package Remedy::Ticket;
our $VERSION = "0.40";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Ticket - manage tickets through the Remedy interface

=head1 SYNOPSIS

    use Remedy::Ticket;

    my $logger = Remedy::Log->get_logger;
    my $remedy = eval { Remedy::Ticket->connect }
        or $logger->logdie ("couldn't connect to database: $@");
    
    my ($number) = @_;
    print scalar $remedy->text ($number, 'primary');
    
=head1 DESCRIPTION

Remedy::Ticket manages tickets in the Remedy system.  It is designed to be able
to handle different types of tickets (incidents vs tasks vs orders, etc) within
the same interface.

Remedy::Ticket is a sub-class of B<Remedy>, with new ticket-specific functions
added.

=cut

##############################################################################
### Configuration ############################################################
##############################################################################

=head1 VARIABLES

=over 4

=item %FORM

Keeps track of the different types of ticket that we manage.  Keys are a short
name, values are the package name that manages that particular type of ticket.
For instance, there is the key I<incident> and the value
B<Remedy::Form::Incident>.

The value for the key I<all> is a special-case; it contains an arrayref of 
package names that we are managing.

We currently only know about incidents.  This will change.

=cut

our %FORM = (
    'all'      => ['Remedy::Form::Incident'],
    'incident' => 'Remedy::Form::Incident',
);

=back

=cut

##############################################################################
### Declarations #############################################################
##############################################################################

use strict;
use warnings;

use Class::Struct;
use Lingua::EN::Inflect qw/inflect/;

use Remedy;
use Remedy::Form::Incident;
use Remedy::Form::People;
use Remedy::Form::SupportGroup;

our @ISA; 
push @ISA, qw/Remedy/;

Remedy::Form->register ('ticket', $FORM{'all'});

##############################################################################
### Subroutines ##############################################################
##############################################################################

=head1 FUNCTIONS

For the most part, these functions take care of all database updates.

=over 4

=item assign (NUMBER, ARGHASH) 

Assigns ticket I<NUMBER> to a given user or group.  I<ARGHASH> must include
either the key I<user> or I<group>.  Uses B<run_on_tickets ()>.

=cut

sub assign  {
    my ($self, $number, @rest) = @_;
    return "no ticket number" unless $number;
    return $self->run_on_tickets ('assign', $number, @rest);
}

=item get (NUMBER)

Looks for the ticket with the number I<NUMBER>.  This means parsing I<NUMBER>
into a full ticket number (B<ticket_number ()> and ticket type (B<ticket_type
()>), then using B<read ()> to find all matching tickets.  In an array context,
returns all of the matching tickts; in a scalar context, only returns the first
one.  In either case, returns undef if nothing matches, and dies if the number 
was in fact bad.

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

=item resolve (NUMBER, TEXT)

Resolves the ticket I<NUMBER> with the text I<TEXT>, using B<run_on_tickets ()>.

=cut

sub resolve {
    my ($self, $number, $text, @rest) = @_;
    return "no ticket number" unless $number;
    return "no resolution text" unless $text;
    return $self->run_on_tickets ('resolve', $number, $text, @rest);
}

=item run_on_tickets (FUNC, NUMBER, ARGS)

Runs the function I<FUNC> (defined with in the appropriate form sub-class, e.g.
B<Remedy::Form::Incident> on all tickets matching I<NUMBER>, and saves them on
success.  Basically, this is the black-magic function of everything.

Returns undef on success, or the text of the errors if there are errors.

=cut

sub run_on_tickets {
    my ($self, $func, $number, @args) = @_;
    my $logger  = $self->logger_or_die;
    my $session = $self->session_or_die;

    $logger->debug ("getting tickets named '$number'");
    my @tickets = $self->get ($number);
    return "no matching ticket" unless scalar @tickets;
    my $errors = 0;
    foreach my $tkt (@tickets) { 
        # my $clone = $tkt->clone;
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
    return;
}

=item set_status (NUMBER, STATUS, REASON)

Sets the status of ticket I<NUMBER> to I<STATUS>.  Note that we do no
error-checking on whether this is a valid status.  I<REASON>, if offered, is
also passed (it is required for some status types).  Uses B<run_on_tickets ()>.

=cut

sub set_status { 
    my ($self, $number, $status, $reason, @rest) = @_;
    return "no ticket number" unless $number;
    return "no status offered" unless $status;
    return $self->run_on_tickets ('set_status', $number, $status, 
        $reason, @rest);
}

=item text (NUMBER [, TYPE])

Returns a nicely formatted string with information about the ticket I<NUMBER>.
I<TYPE> is used to decide which kind of information we want, from the following
list:

=over 4

=item (default)

primary, requestor, assignee, description, resolution, worklog

=item debug

debug

=item audit

primary, audit

=item worklog

primary, worklog

=item summary

primary, summary

=item assign

primary, assignee

=item primary 

primary

=item all, full

Adds 'audit' and 'summary' the default list.

=back

Does not use B<run_on_ticket ()>, for a change.  Dies if there is no relevant
ticket.

=cut

sub text { 
    my ($self, $number, $type) = @_;
    my $logger = $self->logger_or_die;

    $type ||= '';
    my @list = qw/primary requestor assignee description resolution worklog/;
    if    (lc $type eq 'debug')      { @list = qw/debug/             } 
    elsif (lc $type eq 'audit')      { @list = qw/primary audit/     } 
    elsif (lc $type eq 'worklog')    { @list = qw/primary worklog/   } 
    elsif (lc $type eq 'summary')    { @list = qw/primary summary/   } 
    elsif (lc $type eq 'assign')     { @list = qw/primary assignee/  }
    elsif (lc $type eq 'primary')    { @list = qw/primary/           }
    elsif ($type =~ /^(all|full)$/i) { push @list, qw/audit summary/ } 
    $logger->debug ('text types: ' . join (', ', @list));

    local $@;
    my $tkt = eval { $self->get ($number) };
    $logger->logdie ("error loading '$number': $@") if $@ || !$tkt;

    return $tkt->print (@list);
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

Based on I<NUMBER>, says what kind of ticket type this should be.  We determine
this by looking at the first three letters of the number:

=over 4

=item INC => I<incident>

=item TAS => I<task> 

Not supported.

=item HD0 => I<order>

Not supported.

=back

Returns the ticket type, or 'unknown' if we can't tell.

=cut

sub ticket_type {
    my ($self, $num) = @_;
    my $incident = $self->ticket_number ($num) || '';
    if    ($incident =~ /^INC/) { return 'incident' }
    elsif ($incident =~ /^TAS/) { return 'task'     }
    elsif ($incident =~ /^HD0/) { return 'order'    }
    else                        { return 'unknown'  } 
}

=item time_spent (NUMBER, MINUTES)

Adds I<MINUTES> minutes of work to ticket I<NUMBER>, using B<run_on_tickets
()>.

=cut

sub time_add {
    my ($self, $number, $mins, @rest) = @_;
    return "no ticket number" unless $number;
    return "invalid number of minutes" unless $mins > 0;
    return $self->run_on_tickets ('time_add', $number, $mins, @rest);
}

=item unassign (NUMBER)

"Unassigns" a ticket, which means clearing the user field and sending it back
to the top-level help desk (as defined in I<helpdesk> as part of
B<Remedy::Config>).  Uses B<run_on_tickets ()>.

=cut

sub unassign {
    my ($self, $number) = @_;
    return "no ticket number" unless $number;
    return $self->run_on_tickets ('assign', $number, 'user' => undef, 
        'group' => $self->config_or_die->helpdesk);
}

=back

=cut

##############################################################################
### Final Documentation ######################################################
##############################################################################

=head1 REQUIREMENTS

B<Class::Struct>, B<Remedy::Form>, B<Remedy::Form::Incident>

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
