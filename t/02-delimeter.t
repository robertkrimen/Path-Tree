#!/usr/bin/env perl

use strict;
use warnings;

use Test::Most;

plan qw/no_plan/;

use Path::TreeDispatcher;

my $builder = Path::TreeDispatcher::Builder->new( delimeter => '/' );

sub on (@) {
    return $builder->parse_branch( @_ );
}

{
    my @sequence;
    my $root = on( undef,
        sub { 
            undef @sequence;
        },
        on( 'apple',
            'Apple',
            on( 'banana',
                'Apple+Banana',
            ),
            on( 'cherry',
                'Apple+Cherry',
            ),
            on( 'grape',
                'Apple+Grape',
            ),
            on( [qw/ lemon lime /],
                'Lemon+Lime',
            ),
        ),
    );

    my $dispatcher = Path::TreeDispatcher->new( root => $root, visitor => sub {
        my $ctx = shift; 
        my $data = shift;
        if ( ref $data eq 'CODE' ) {
            $data->( $ctx );
        }
        else {
            push @sequence, $data;
        }
    } );
    
    $dispatcher->dispatch( "apple" );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    $dispatcher->dispatch( "apple/banana" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Banana /] );

    $dispatcher->dispatch( "cherry" );
    cmp_deeply( \@sequence, [] );

    $dispatcher->dispatch( "apple/cherry" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Cherry /] );

    $dispatcher->dispatch( "///apple/" );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    $dispatcher->dispatch( "apple//banana" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Banana /] );

    $dispatcher->dispatch( "cherry///" );
    cmp_deeply( \@sequence, [] );

    $dispatcher->dispatch( "apple//cherry//" );
    cmp_deeply( \@sequence, [qw/ Apple Apple+Cherry /] );

    $dispatcher->dispatch( "apple//lemon/lime" );
    cmp_deeply( \@sequence, [qw/ Apple Lemon+Lime /] );

    $dispatcher->dispatch( "apple//lemon" );
    cmp_deeply( \@sequence, [qw/ Apple /] );

    $dispatcher->dispatch( "apple//lemon/lim" );
    cmp_deeply( \@sequence, [qw/ Apple /] );
}
