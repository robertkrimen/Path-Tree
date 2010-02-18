use inc::Module::Install;

name     'Path-StepDispatcher';
all_from 'lib/Path/StepDispatcher.pm';
author   q{Robert Krimen <rkrimen@cpan.org>};
license  'perl';

build_requires 'Test::More';

auto_install;

WriteAll;

