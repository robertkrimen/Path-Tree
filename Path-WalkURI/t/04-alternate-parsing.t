#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/ no_plan /;

use Path::WalkURI::Dispatcher;

ok( 1 );

my ( $dispatcher );

$dispatcher = Path::WalkURI::Dispatcher->new;

sub route (@) {
    my $rule = shift;
    my $route = $dispatcher->build_route( rule => $dispatcher->parse_rule( $rule ) );
    $route->add( @_ );
    return $route;
}

{
    $dispatcher->root->add(
        route( qr/apple\/?/,
            'Apple',
            route( qr/banana\/?/, 
                'Apple+Banana',
            ),
            sub {
                diag "Interrupt!";
#                my $ctx = shift;
#                $ctx->path( 'grape' ) if $ctx->path; # Always goes to the grape branch
            },
            route( qr/cherry\/?/, 
                'Apple+Cherry',
            ),
            route( qr/grape\/?/, 
                'Apple+Grape',
            ),
        ),
    );

    my @sequence;
    my @dispatch = ( prepare_walker => sub {
        my $walker = shift;
        $walker->visitor( sub {
            my $walker = shift; 
            my $data = shift;
            if ( ref $data eq 'CODE' ) {
                $data->( $walker );
            }
            else {
                push @sequence, $data;
            }
        } );
    } );

    undef @sequence;
    $dispatcher->dispatch( "apple", @dispatch );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    undef @sequence;
    $dispatcher->dispatch( "apple/banana", @dispatch );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Banana Apple+Grape /] );

    undef @sequence;
    $dispatcher->dispatch( "cherry", @dispatch );
    cmp_deeply( \@sequence, [] );

    undef @sequence;
    $dispatcher->dispatch( "apple/cherry", @dispatch );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Grape /] );
}


