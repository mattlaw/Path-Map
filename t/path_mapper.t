use strict;
use warnings;

use Test::More tests => 16;

use Path::Mapper;

my $mapper = Path::Mapper->new(
    '/x/y/z' => 'XYZ',
    '/a/b/c' => 'ABC',
    '/a/b'   => 'AB',
);

isa_ok($mapper, 'Path::Mapper', 'Path::Mapper->new');

$mapper->add_handler('/date/:year/:month/:day' => 'Date');

# lots of different versions of the same path, all should match the same
my @variations = (
    'date/2012/12/25',
    '/date/2012/12/25',
    '/date/2012/12/25/',
    'date/2012/12/25/',
    '//date//2012/12/25'
);

for my $path (@variations) {
    my $match = $mapper->lookup($path);
    ok $match, "lookup('$path')";
    is $match->handler, 'Date', '.. mapped to Date';
    is_deeply(
        $match->variables,
        { year => 2012, month => 12, day => 25 },
        '.. correct variables'
    );
}

