package Path::Mapper::Match;

use strict;
use warnings;

=head1 NAME

Path::Mapper::Match - Match object for Path::Mapper

=cut

sub new {
    my ($class, %attributes) = @_;
    return bless \%attributes, $class;
}

sub mapper { $_[0]->{mapper} }
sub values { $_[0]->{values} ||= [] }
sub handler { $_[0]->mapper->_target }

sub variables {
    my $self = shift;

    my %vars;
    @vars{ @{ $self->mapper->_variables } } = @{ $self->values };

    return \%vars;
}

1;
