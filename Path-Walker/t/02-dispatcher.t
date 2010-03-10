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

$dispatcher->plot(

    '/apple' => sub {
        diag "Apple";
    },

    '/*' => [
        '/cherry' => sub {
            diag "Cherry";
        },

        '/*/*' => sub {
            diag "/*/*";
        },

        sub {
            diag "After /*/*";
        },

        '' => sub {
            diag "/*";
        },

        -before => sub {
            diag "Before /*";
        },
    ],
);

$dispatcher->dispatch( '/apple' );
$dispatcher->dispatch( '/apple/cherry' );
$dispatcher->dispatch( '/banana' );
$dispatcher->dispatch( '/banana/cherry' );
$dispatcher->dispatch( '/banana/0/1/grape' );
$dispatcher->dispatch( '/banana/grape' );
