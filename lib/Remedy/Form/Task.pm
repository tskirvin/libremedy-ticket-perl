package Remedy::Form::Task;
our $VERSION = "0.12";
our $ID = q$Id: Remedy.pm 4743 2008-09-23 16:55:19Z tskirvin$;
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Task - ticket-generation table

=head1 SYNOPSIS

    use Remedy;
    use Remedy::Task;

    [...]

=head1 DESCRIPTION

Remedy::Task tracks [...] 
It is a sub-class of B<Stanford::Packages::Form>, so
most of its functions are described there.

=cut

##############################################################################
### Declarations
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

use Remedy::Ticket;

our @ISA = init_struct (__PACKAGE__, 'ticketgen' => 'Remedy::Form::TicketGen');
unshift @ISA, 'Remedy::Ticket::Functions'; 

Remedy::Form->register ('task', __PACKAGE__);

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
    'number'                => 'Task ID',

    'assignee'              => 'Assignee',
    'assignee_group'        => 'Assignee Group',
    'assignee_netid'        => 'Assigned To',
    'date_modified'         => "Modified Date",
    'netid'                 => 'Submitter',
    'requestor_first_name'  => "First Name",
    'requestor_last_name'   => "Last Name",

}

sub limit_pre {
    my ($self, %args) = @_;
    my $parent = $self->parent_or_die ();
    my $config = $parent->config_or_die ('no configuration');

    if (my $type = $args{'type'}) { 
        return unless $type =~ /^(task|all|%)$/i;
        delete $args{'type'};
    }
    
    if (my $number = $args{'number'}) { return ('Task ID' => $number) }

    my @extra;
    if (my $extra = $args{'extra'}) { 
        @extra = ref $extra ? @$extra : $extra;
        delete $args{'extra'};
    }
    
    if (scalar @extra) { $args{'extra'} ||= [@extra] }

    return %args;
}

sub limit_status { }

=item name ()

=cut

sub name {
    my ($self, %args) = @_;
    return $self->inc_num;
}

=item table ()

=cut

sub table { 'TMS:Task' }

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
