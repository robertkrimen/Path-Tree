#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

package main;

use Path::Walker::Dispatcher;

my ( $dispatcher );

$dispatcher = Path::Walker::Dispatcher->new(
    parse_rule => {
        '' => sub {
            my $parser = shift;
            return $parser->build( 'SlashPattern' => pattern => shift );
        },
    }
);

ok( $dispatcher );

my @got;
$dispatcher->plot(

    '/apple' => sub {
        push @got, qw/Apple/;
    },

    '/*' => [
        '/cherry' => sub {
            push @got, qw/Cherry/;
        },

        '/*/*' => sub {
            push @got, qw/**/;
        },

        sub {
            push @got, qw/{}/;
        },

        '' => sub {
            push @got, qw/*/;
        },

        -before => sub {
            push @got, qw/Before*/;
        },
    ],
);

sub test_dispatch {
    my $path = shift;
    undef @got;
    $dispatcher->dispatch( $path );
    cmp_deeply( \@got, [ @_ ] ) or diag "\@got = ", join ' | ', @got;
}

test_dispatch( '/apple', qw/ Apple / );
test_dispatch( '/apple/cherry', qw/ Apple / );
test_dispatch( '/banana', qw/ Before* {} * / );
test_dispatch( '/banana/cherry', qw/ Before* Cherry / );
test_dispatch( '/banana/0/1/grape', qw/ Before* ** / );
test_dispatch( '/banana/grape', qw/ Before* {} * / );
