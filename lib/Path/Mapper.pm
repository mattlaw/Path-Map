package Path::Mapper;

use strict;
use warnings;

=head1 NAME

Path::Mapper - map things into a path-like structure

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

Only the methods which comprise the main interface of this class are described
here. See L</EXTENDING> for information about other methods which may be
useful to subclasses.

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
                return $mapper->_no_match($segment, \@parts, \@values);
            }

            $mapper = $next;
        }
        elsif ($mapper->_is_endpoint) {
            return $mapper->_match_with_values(\@values);
        }
        else {
            return $mapper->_exhausted(\@values);
        }
    }
}

=head2 handlers

    @handlers = $mapper->handlers()

Returns all of the handlers in no particular order.

=cut

sub handlers {
    my $self = shift;

    return (
        grep defined, $self->_target, map $_->handlers, values %{ $self->_map }
    );
}

=head1 EXTENDING

This class has been designed with subclassing in mind, with fine-grained
private methods available to be overridden to fine-tune behaviour.

It's obviously also possible to override the main interface methods too, which
would allow for interface compatibility between wildly differnt mapping
schemes. The constructor has been specifically designed to allow for
non-string "path template" elements as well as "handlers", so a custom
C<add_handler> method could be made to make mappings based on regular
expressions or objects.

It should be noted that heterogeneous mappers are explicitly I<not> supported.
There is an assumption that all objects in the tree are of the same class,
with the same lookup rules, this allows us to optimise lookup by avoiding
subroutine-level recursion.

=over

=item _tokenise_path

Used by both C<add_handler> and C<lookup> to transform a path or path template
into a list of path segments.

This method could be overridden to change the path delimiter to something
other than a slash, or to map paths with leading slashes differently to those
without.

=cut

sub _tokenise_path {
    my ($self, $path) = @_;

    return grep length, split '/', $path;
}

=item _is_endpoint

Returns true if the current mapping object has a handler associated with it.
This could be overridden to return true all the time, which would force a
match object to be returned even when the match is incomplete (i.e. C<<
$match->handler >> is C<undef>).

=cut

sub _is_endpoint {
    my $self = shift;

    return defined $self->_target;
}

=item _match_with_values

This is the return value of C<lookup> when a successful match has occurred.

The parameter is an arrayref of variable values gathered along the way.

This implementation constructs a L<Path::Mapper::Match> object, passing
C<mapper> and C<values> parameters.

=cut

sub _match_with_values {
    my ($self, $values) = @_;

    return $self->_match_class->new( mapper => $self, values => $values );
}

=item _match_class

The class of object to return on a successful match. This can be overridden on
its own to return an object that's compatible with L<Path::Mapper::Match>.

=cut

sub _match_class { 'Path::Mapper::Match' }

=item _no_match

This is the return value of C<lookup> when a mapper doesn't have a matching
segment for the next part of the path. The parameters passed in are 

=over

=item The path segment which didn't match

=item An arrayref of segments following this

=item An arrayref of variable values gathered so far

=back

This implementation simply returns C<undef>, ignoring the parameters.

=cut

sub _no_match { return undef }

=item _exhausted

This is the return value of C<lookup> when the path segments have been
exhausted without an endpoint being found.

The parameter is an arrayref of variable values gathered so far.

This implementation simply returns C<undef>, ignoring the parameters.

=cut

sub _exhausted { return undef }

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
