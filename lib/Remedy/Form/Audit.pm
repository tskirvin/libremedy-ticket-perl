package Remedy::Form::Audit;
our $VERSION = "0.50";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Audit - per-ticket worklogs

=head1 SYNOPSIS

    use Remedy::Audit;

    # $remedy is a Remedy object
    my @audit = $remedy->read ('EID' => 'INC000000002371');
    for my $item (@audit) { print scalar $item->print_text }

=head1 DESCRIPTION

Remedy::Audit monitors the automatically-generated audit logs for each
incident.  It is a sub-class of B<Remedy::Form>, and most of its functionality
is described there.  It is meant for use with the B<Remedy::Incident> and
B<Remedy::Task> tables.

=cut

##############################################################################
### Declarations
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

our @ISA = init_struct (__PACKAGE__);

##############################################################################
### Methods 
##############################################################################

=head1 FUNCTIONS

=head2 B<Class::Struct> Accessors

=over 4

=item id ($)

Corresponds to 'Request ID' field.

=item create_time ($)

Corresponds to 'Create Date' field.

=item inc_ref ($)

Corresponds to 'Original Request ID' field.

=item user ($)

Corresponds to 'User' field.

=item fields ($)

Corresponds to 'Fields Changed' field.

=item data ($)

Corresponds to 'Log' field.

=back

=cut

sub field_map { 
    'id'          => 'Request ID',
    'create_time' => 'Create Date',
    'number'      => "Original Request ID",
    'user'        => "User",
    'changes'     => "Fields Changed",
    'data'        => "Log",
}

=item limit_pre ()

=cut

sub limit_pre {
    my ($self, %args) = @_;
    my $parent = $self->parent_or_die ();

    if (my $eid = $args{'PARENT'}) { return ('Original Request ID' => $eid); }

    return %args;
}

=item print ()

Returns a short list of the salient points of the audit entry - the creation
time, the person that made the changes, and a list of changed fields.

=cut

sub print {
    my ($self, %args) = @_;

    my @changes = split (';', $self->changes);
    my @parse   = grep { $_ } @changes;

    my @return = $self->format_text_field (
        {'minwidth' => 20, 'prefix' => '  '}, 
        'Time'   => $self->create_time,
        'Person' => $self->user,
        'Changed Fields' => join ('; ', @parse),
    );

    return wantarray ? @return : join ("\n", @return, '');
}

=item table ()

=cut

sub table { 'HPD:HelpDesk_AuditLogSystem' }

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
