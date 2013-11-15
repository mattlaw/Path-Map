use strict;
use warnings;

use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Path::Mapper',
    license             => 'perl',
    dist_author         => 'Matt Lawrence <mattlaw@cpan.org>',
    requires => {
        'perl' => '5.8.0',
        'List::Util' => 0,
    },
    build_requires => {
        'Test::More' => 0,
    },
    configure_requires => {
        'Module::Build' => '0.40',
    },
    create_makefile_pl => 'small',
);

$builder->create_build_script;
