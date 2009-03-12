package Remedy::Form::Audit;
our $VERSION = "0.50";
# Copyright and license are in the documentation below.

=head1 NAME

Remedy::Form::Audit - per-ticket worklogs

=head1 SYNOPSIS

    use Remedy::Form::Audit;

    # $remedy is a Remedy object
    foreach my $audit ($remedy->read ('audit', 'PARENT' => 
        'INC000000002371')) {
        print scalar $entry->print_text 
    }

=head1 DESCRIPTION

Remedy::Form::Audit manages the I<HPD:HelpDesk_AuditLogSystem> form in Remedy,
which tracks all edits to the remedy database.  

Remedy::Form::Audit is a sub-class of B<Remedy::Form>, registered as I<audit>.

=cut

##############################################################################
### Declarations #############################################################
##############################################################################

use strict;
use warnings;

use Remedy::Form qw/init_struct/;

our @ISA = init_struct (__PACKAGE__);

##############################################################################
### Class::Struct ############################################################
##############################################################################

=head1 FUNCTIONS

=head2 B<Class::Struct> Accessors

=over 4

=item id (I<Request ID>)

=item changes (I<Fields Changed>)

=item create_time (I<Create Date>)

=item data (I<Log>)

=item number (I<Original Request ID>)

=item user (I<User>)

=back

=cut

sub field_map { 
    'id'          => 'Request ID',
    'changes'     => "Fields Changed",
    'create_time' => 'Create Date',
    'data'        => "Log",
    'number'      => "Original Request ID",
    'user'        => "User",
}

##############################################################################
### Remedy::Form Overrides ###################################################
##############################################################################

=head2 B<Remedy::Form> Overrides

=over 4

=item limit_pre (ARGHASH)

=over 4

=item PARENT I<number>

If set, then we will search based on the I<Original Request ID> field.

=back

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
