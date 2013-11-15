package Path::Mapper;

use strict;
use warnings;

=head1 NAME

Path::Mapper - map paths to handlers

=head1 VERSION

0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    my $mapper = Path::Mapper->new(
        '/x/y/z' => 'XYZ',
        '/a/b/c' => 'ABC',
        '/a/b'   => 'AB',

        '/date/:year/:month/:day' => 'Date',
    );

    if (my $match = $mapper->lookup('/date/2013/12/25')) {
        # $match->handler is 'Date'
        # $match->variables is { year => 2012, month => 12, day => 25 }
    }

    # Add more mappings later
    $mapper->add_handler($path => $target)

=head1 DESCRIPTION

This class maps arbitrary items into a path-like structure, which can contain
variable path segments, and allows them to be retrieved again. The most
obvious application of this is to map paths to action handlers, so for this
reason we refer to the items being mapped to by the paths as "handlers".

=cut

use List::Util qw( reduce );
use List::MoreUtils qw( uniq natatime );

use Path::Mapper::Match;

=head1 METHODS

=head2 new

    $mapper = $class->new(@pairs)

The constructor.

Takes an even-sized list and passes each pair to L</add_handler>.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my $iterator = natatime 2, @_;
    while (my @pair = $iterator->()) {
        $self->add_handler(@pair);
    }

    return $self;
}

=head2 add_handler

    $mapper->add_handler($path_template, $handler)

Adds a single item to the mapping.

The path template should be a string comprising slash-delimited path segments,
where a path segment may contain any character other than the slash. Any
segment beginning with a colon (C<:>) denotes a mandatory named variable.
Empty segments, including those implied by leading or trailing slashes are
ignored.

For example, these are all identical path templates:

    /a/:var/b
    a/:var/b/
    //a//:var//b//

The order in which these templates are added has no bearing on the lookup,
except that later additions with identical templates overwrite earlier ones.

=cut

sub add_handler {
    my ($self, $path, $handler) = @_;
    my $class = ref $self;

    my @parts = $self->_tokenise_path($path);
    my @vars;
    my $mapper = reduce {
        $b =~ s{^:(.*)}{/} and push @vars, $1;
        $a->_map->{$b} ||= $class->new;
    } $self, @parts;

    $mapper->_set_target($handler);
    $mapper->_set_variables(\@vars);

    return;
}

=head2 lookup

    $match = $mapper->lookup($path)

Returns a L<Path::Mapper::Match> object if the path matches a known path
template, C<undef> otherwise.

The two main methods on the match object are

=over

=item handler

The handler that was matched, identical to whatever was originally passed to
L</add_handler>.

=item variables

The named path variables as a hashref.

=back

=cut

sub lookup {
    my ($mapper, $path) = @_;

    my @parts = $mapper->_tokenise_path($path);
    my @values;

    while () {
        if (my $segment = shift @parts) {
            my $map = $mapper->_map;

            my $next;
            if ($next = $map->{$segment}) {
                # Nothing
            }
            elsif ($next = $map->{'/'}) {
                push @values, $segment;
            }
            else {
                return undef;
            }

            $mapper = $next;
        }
        elsif (defined $mapper->_target) {
            return Path::Mapper::Match->new(
                mapper => $mapper,
                values => \@values
            );
        }
        else {
            return undef;
        }
    }
}

=head2 handlers

    @handlers = $mapper->handlers()

Returns all of the handlers in no particular order.

=cut

sub handlers {
    my $self = shift;

    return uniq(
        grep defined, $self->_target, map $_->handlers, values %{ $self->_map }
    );
}

sub _tokenise_path {
    my ($self, $path) = @_;

    return grep length, split '/', $path;
}

sub _map { $_[0]->{map} ||= {} }

sub _target     { $_[0]->{target} }
sub _set_target { $_[0]->{target} = $_[1] }

sub _variables     { $_[0]->{vars} || [] }
sub _set_variables { $_[0]->{vars} = $_[1] }

=head1 SEE ALSO

L<Path::Router>, a more heavy-duty solution with more features but less
performance.

=cut

1;
